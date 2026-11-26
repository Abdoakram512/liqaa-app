"""Generate clean, anatomically accurate, halo-free 2.5D rig parts for Yasser.

All parts are derived directly from Yasser's authentic artwork assets and
aligned to Yasser_Phase1_Work (artboard 5-1, 486x695) bone coordinates.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(r"E:\Flutter Projects\liqaa_app")
RIVE_TOOLS = ROOT / "tools" / "rive" / "yasser"
OUT_DIR = RIVE_TOOLS / "generated_parts"
OUT_DIR.mkdir(parents=True, exist_ok=True)


def recolor_edge_decontaminate(img: Image.Image) -> Image.Image:
    """Remove dark/light premultiply edge halos around alpha cutouts."""
    arr = np.array(img.convert("RGBA")).astype(np.float32)
    rgb = arr[:, :, :3]
    opaque = arr[:, :, 3] > 210
    if opaque.any():
        blurred = np.array(
            img.convert("RGB").filter(ImageFilter.GaussianBlur(radius=1.8))
        ).astype(np.float32)
        trans = (arr[:, :, 3] > 2) & (arr[:, :, 3] < 210)
        rgb[trans] = 0.30 * rgb[trans] + 0.70 * blurred[trans]
    out = np.concatenate([np.clip(rgb, 0, 255), arr[:, :, 3:4]], axis=2)
    return Image.fromarray(out.astype(np.uint8), "RGBA")


def build_clean_sleeve(src_path: Path, is_left_screen: bool) -> Image.Image:
    """Extract sleeve above cuff with a seamless, zero-sliver rounded shoulder cap."""
    im = Image.open(src_path).convert("RGBA")
    arr = np.array(im).astype(np.float32)
    h, w, _ = arr.shape
    yy, xx = np.mgrid[0:h, 0:w]

    # Cut cleanly at wrist cuff (y=230.5) so zero static skin peeks when wrist rotates
    cx = 76.0 if is_left_screen else 87.0
    cuff_curve = 230.5 + 2.0 * np.clip(1.0 - ((xx - cx) / 18.0) ** 2, 0.0, 1.0)
    arr[:, :, 3] *= np.clip((cuff_curve + 1.0 - yy) / 1.8, 0.0, 1.0)

    # Trim only the oversized top bulb above y=129 while keeping a full solid convex
    # shoulder circle centered around the shoulder joint so raising arms 0..180 deg
    # never opens an armpit gap and rest never shows a strap gap.
    if is_left_screen:
        top_clip = np.clip((yy - (129.0 + np.maximum(0.0, 74.0 - xx) * 0.18)) / 2.0, 0.0, 1.0)
        strap_shadow = np.exp(-((xx - 92.0) ** 2) / 20.0) * np.clip((175.0 - yy) / 40.0, 0.0, 1.0)
    else:
        top_clip = np.clip((yy - (129.0 + np.maximum(0.0, xx - 88.0) * 0.18)) / 2.0, 0.0, 1.0)
        strap_shadow = np.exp(-((xx - 72.0) ** 2) / 20.0) * np.clip((175.0 - yy) / 40.0, 0.0, 1.0)

    arr[:, :, 3] *= top_clip
    arr[:, :, :3] *= 1.0 - 0.14 * strap_shadow[:, :, None]

    # Hard-zero near-invisible alpha pixels (<12) so contour mesh tracing never catches edge slivers
    out = recolor_edge_decontaminate(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"))
    oarr = np.array(out)
    oarr[oarr[:, :, 3] < 12, 3] = 0
    return Image.fromarray(oarr, "RGBA")


def place_hand_bone_aligned(
    hand_crop: Image.Image,
    src_wrist: Tuple[float, float],
    finger_dir_deg: float,
    target_length: float,
    canvas_size: int = 160,
    wrist_pivot: Tuple[int, int] = (48, 80),
) -> Image.Image:
    """Rotate/scale a cropped hand so wrist sits at wrist_pivot and fingers point +X."""
    arr = np.array(hand_crop.convert("RGBA"))
    ys, xs = np.where(arr[:, :, 3] > 64)
    rad = math.radians(finger_dir_deg)
    proj = (xs - src_wrist[0]) * math.cos(rad) + (ys - src_wrist[1]) * math.sin(rad)
    curr_len = max(10.0, float(proj.max()))
    scale = target_length / curr_len

    nw = max(16, int(round(hand_crop.width * scale)))
    nh = max(16, int(round(hand_crop.height * scale)))
    scaled = hand_crop.resize((nw, nh), Image.Resampling.LANCZOS)
    swx, swy = src_wrist[0] * scale, src_wrist[1] * scale

    pad = max(nw, nh) * 2
    padded = Image.new("RGBA", (pad, pad), (0, 0, 0, 0))
    ox = pad // 2 - int(round(swx))
    oy = pad // 2 - int(round(swy))
    padded.paste(scaled, (ox, oy), scaled)

    rotated = padded.rotate(finger_dir_deg, resample=Image.Resampling.BICUBIC, expand=False)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.paste(rotated, (wrist_pivot[0] - pad // 2, wrist_pivot[1] - pad // 2), rotated)
    return recolor_edge_decontaminate(canvas)


def apply_rounded_wrist_clip(img: Image.Image, wrist_x: float = 48.0, wrist_y: float = 80.0, wrist_radius: float = 11.5) -> Image.Image:
    """Clip protruding wrist edge corners to a smooth rounded wrist tab behind the cuff."""
    arr = np.array(img.convert("RGBA")).astype(np.float32)
    h, w, _ = arr.shape
    yy, xx = np.mgrid[0:h, 0:w]
    # Keep everything >= wrist_x smoothly intact; to the left of wrist_x, round cleanly with capsule radius
    dx = np.maximum(0.0, wrist_x - xx)
    dy = np.abs(yy - wrist_y)
    dist = np.sqrt(dx ** 2 + dy ** 2) - wrist_radius
    left_mask = np.where(xx < wrist_x, np.clip(0.5 - dist / 2.0, 0.0, 1.0), 1.0)
    arr[:, :, 3] *= left_mask
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def build_relaxed_hands() -> Tuple[Image.Image, Image.Image]:
    """Extract clean Screen-Left (Anatomical Right) & Screen-Right (Anatomical Left) relaxed hands."""
    al = Image.open(RIVE_TOOLS / "Relaxed_Arm_Screen_Left.png").convert("RGBA")
    arr_l = np.array(al).astype(np.float32)
    h, w, _ = arr_l.shape
    yy, _ = np.mgrid[0:h, 0:w]
    arr_l[:, :, 3] *= np.clip((yy - 224.0) / 4.0, 0.0, 1.0)
    yellow_wrist = (yy >= 224) & (yy <= 235) & (arr_l[:, :, 3] > 10) & (arr_l[:, :, 2] < 45)
    arr_l[yellow_wrist, 0:3] = [218.0, 136.0, 78.0]
    crop_l = Image.fromarray(np.clip(arr_l, 0, 255).astype(np.uint8), "RGBA").crop((40, 222, 120, 290))
    hand_l = place_hand_bone_aligned(crop_l, src_wrist=(37.0, 11.0), finger_dir_deg=78.4, target_length=47.0)
    hand_l = apply_rounded_wrist_clip(hand_l, wrist_x=48.0, wrist_y=80.0, wrist_radius=12.0)

    ar = Image.open(RIVE_TOOLS / "Relaxed_Arm_Screen_Right.png").convert("RGBA")
    arr_r = np.array(ar).astype(np.float32)
    arr_r[:, :, 3] *= np.clip((yy - 224.0) / 4.0, 0.0, 1.0)
    yellow_wrist_r = (yy >= 224) & (yy <= 235) & (arr_r[:, :, 3] > 10) & (arr_r[:, :, 2] < 45)
    arr_r[yellow_wrist_r, 0:3] = [218.0, 136.0, 78.0]
    crop_r = Image.fromarray(np.clip(arr_r, 0, 255).astype(np.uint8), "RGBA").crop((50, 222, 130, 290))
    hand_r = place_hand_bone_aligned(crop_r, src_wrist=(37.0, 11.0), finger_dir_deg=103.2, target_length=47.0)
    hand_r = apply_rounded_wrist_clip(hand_r, wrist_x=48.0, wrist_y=80.0, wrist_radius=12.0)
    return hand_l, hand_r


def draw_palm_hand(thumb_on_bottom: bool) -> Image.Image:
    """Render a crisp 2.5D open waving palm pointing +X from wrist (48, 80).

    Uses Yasser's authentic Wave hand colors/highlights with zero stray cutout halo:
    - Soft warm palm crease, NO fingernails (palm faces viewer).
    - thumb_on_bottom=True  -> Hand_L_Palm (bone 6-6 raised: +Y is INNER toward head).
    - thumb_on_bottom=False -> Hand_R_Palm (bone 6-9 raised: -Y is INNER toward head).
    """
    w, h = 160, 160
    ss = 4
    arr = np.zeros((h * ss, w * ss, 4), dtype=np.float32)
    yy, xx = np.mgrid[0 : h * ss, 0 : w * ss]

    # Build open palm union SDF (wrist circle + broad rounded palm + 4 fanned fingers + angled thumb)
    # Coordinates in 160x160 space: wrist center (48, 80)
    def capsule_sdf(x0: float, y0: float, x1: float, y1: float, r0: float, r1: float) -> np.ndarray:
        vx, vy = (x1 - x0) * ss, (y1 - y0) * ss
        wx, wy = xx - x0 * ss, yy - y0 * ss
        vlen2 = max(1e-5, vx * vx + vy * vy)
        t = np.clip((wx * vx + wy * vy) / vlen2, 0.0, 1.0)
        px = x0 * ss + t * vx
        py = y0 * ss + t * vy
        rad = (r0 + (r1 - r0) * t) * ss
        return np.sqrt((xx - px) ** 2 + (yy - py) ** 2) - rad

    def smin(a: np.ndarray, b: np.ndarray, k: float) -> np.ndarray:
        h_s = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
        return b * (1.0 - h_s) + a * h_s - k * h_s * (1.0 - h_s)

    sign = 1.0 if thumb_on_bottom else -1.0  # +1 puts thumb at bottom (+Y), -1 puts thumb at top (-Y)

    # Palm base + rounded wrist anchor
    d_palm = capsule_sdf(45.0, 80.0, 67.0, 80.0, 10.5, 16.5)
    # Add palm width fullness on finger/thumb bridge
    d_bridge = capsule_sdf(61.0, 80.0 - 4.0 * sign, 72.0, 80.0 - 2.0 * sign, 11.5, 13.0)
    d = smin(d_palm, d_bridge, 6.0 * ss)

    # Thumb on inner side (`sign`), gently abducted ~40 deg forward
    d_thumb = capsule_sdf(55.0, 80.0 + 9.0 * sign, 74.0, 80.0 + 23.0 * sign, 6.0, 4.8)
    d = smin(d, d_thumb, 4.5 * ss)

    # 4 fanned open fingers (Index closest to thumb -> Little furthest)
    d_idx = capsule_sdf(72.0, 80.0 + 6.8 * sign, 94.5, 80.0 + 10.2 * sign, 4.3, 3.7)
    d_mid = capsule_sdf(74.0, 80.0 + 0.2 * sign, 99.5, 80.0 + 0.2 * sign, 4.4, 3.8)
    d_rng = capsule_sdf(72.5, 80.0 - 6.5 * sign, 95.5, 80.0 - 10.0 * sign, 4.2, 3.6)
    d_lit = capsule_sdf(69.0, 80.0 - 12.2 * sign, 88.5, 80.0 - 18.2 * sign, 3.8, 3.2)

    for df in (d_idx, d_mid, d_rng, d_lit):
        d = smin(d, df, 2.2 * ss)

    alpha = np.clip(0.5 - d / 2.2, 0.0, 1.0)

    # Soft 2.5D palm shading matching Yasser skin: luminous peach-cream center, warm terracotta rim
    # Light from top-left (-0.5, -0.8) + soft pillowy ambient occlusion around palm edge
    interior = np.clip(-d / (14.0 * ss), 0.0, 1.0)
    light_y = np.clip(0.55 - ((yy - 80.0 * ss) / (30.0 * ss)) * 0.25, 0.2, 0.9)
    pillow = 0.45 * np.sqrt(interior) + 0.55 * light_y

    col_r = 224.0 + 31.0 * pillow
    col_g = 138.0 + 66.0 * pillow
    col_b = 82.0 + 68.0 * pillow

    # Warm soft palm crease arc on center of palm (NO fingernails, ultra-soft 3D look!)
    d_crease = np.abs(capsule_sdf(62.0, 80.0 + 4.5 * sign, 72.0, 80.0 - 5.5 * sign, 1.3, 1.0))
    crease_mask = np.clip(1.0 - d_crease / (2.0 * ss), 0.0, 1.0) * 0.16
    d_thenar = np.abs(capsule_sdf(56.0, 80.0 + 5.5 * sign, 64.0, 80.0 + 1.0 * sign, 1.1, 1.0))
    thenar_mask = np.clip(1.0 - d_thenar / (2.0 * ss), 0.0, 1.0) * 0.12
    creases = np.maximum(crease_mask, thenar_mask)
    col_r = col_r * (1.0 - creases) + 202.0 * creases
    col_g = col_g * (1.0 - creases) + 122.0 * creases
    col_b = col_b * (1.0 - creases) + 74.0 * creases

    # Very subtle inner contour shading matching Yasser's 2.5D hand style
    edge_band = np.exp(-((d + 1.2 * ss) ** 2) / (3.2 * ss * ss)) * 0.08
    col_r -= 40.0 * edge_band
    col_g -= 45.0 * edge_band
    col_b -= 34.0 * edge_band

    arr[:, :, 0] = np.clip(col_r, 0, 255)
    arr[:, :, 1] = np.clip(col_g, 0, 255)
    arr[:, :, 2] = np.clip(col_b, 0, 255)
    arr[:, :, 3] = np.clip(alpha * 255.0, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w, h), Image.Resampling.LANCZOS)


def draw_soft_finger(
    length: float,
    thickness: float,
    tip_taper: float = 0.86,
    nail: bool = True,
) -> Image.Image:
    """Render a soft 2.5D rounded finger pointing +X from knuckle base (16, 20)."""
    w, h = 64, 40
    ss = 4
    arr = np.zeros((h * ss, w * ss, 4), dtype=np.float32)
    yy, xx = np.mgrid[0 : h * ss, 0 : w * ss]

    x0 = 16.0 * ss
    x1 = (16.0 + length) * ss
    yc = 20.0 * ss
    r_base = (thickness * 0.5) * ss

    t = np.clip((xx - x0) / max(1.0, (x1 - x0)), 0.0, 1.0)
    r_local = r_base * (1.0 - (1.0 - tip_taper) * (t ** 1.4))
    px = np.clip(xx, x0, x1)
    dist = np.sqrt((xx - px) ** 2 + (yy - yc) ** 2) - r_local
    alpha = np.clip(0.5 - dist / 2.2, 0.0, 1.0)

    ny = (yy - yc) / np.maximum(1.0, r_local)
    shade = np.clip(0.56 - 0.32 * ny + 0.14 * np.sin(t * math.pi), 0.0, 1.0)
    col_r = 215.0 + 38.0 * shade
    col_g = 128.0 + 62.0 * shade
    col_b = 74.0 + 66.0 * shade

    edge_band = np.exp(-((dist + 1.4) ** 2) / 2.6)
    col_r -= 28.0 * edge_band
    col_g -= 32.0 * edge_band
    col_b -= 24.0 * edge_band

    if nail:
        nx_c = x1 - 4.0 * ss
        nail_d = np.sqrt(((xx - nx_c) / (3.4 * ss)) ** 2 + ((yy - yc) / (r_local * 0.58)) ** 2)
        nail_m = np.clip((1.0 - nail_d) * 3.5, 0.0, 1.0) * 0.72
        col_r = col_r * (1.0 - nail_m) + 255.0 * nail_m
        col_g = col_g * (1.0 - nail_m) + 214.0 * nail_m
        col_b = col_b * (1.0 - nail_m) + 188.0 * nail_m

    arr[:, :, 0] = np.clip(col_r, 0, 255)
    arr[:, :, 1] = np.clip(col_g, 0, 255)
    arr[:, :, 2] = np.clip(col_b, 0, 255)
    arr[:, :, 3] = np.clip(alpha * 255.0, 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w, h), Image.Resampling.LANCZOS)


def draw_dorsal_hand_cover(
    thumb_on_top: bool,
    include_fingers: bool = True,
) -> Image.Image:
    """Create a crisp 2.5D dorsal (back-of-hand) cover hand pointing +X from wrist (48, 80)."""
    w, h = 160, 160
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    ss = 4
    arr = np.zeros((h * ss, w * ss, 4), dtype=np.float32)
    yy, xx = np.mgrid[0 : h * ss, 0 : w * ss]

    t = np.clip((xx - 43.0 * ss) / (33.0 * ss), 0.0, 1.0)
    half_h = (9.5 + 6.5 * t) * ss
    yc = 80.0 * ss
    px = np.clip(xx, 46.0 * ss, 75.0 * ss)
    py = np.clip(yy, yc - half_h + 4.0 * ss, yc + half_h - 4.0 * ss)
    dist_p = np.sqrt((xx - px) ** 2 + (yy - py) ** 2) - 5.5 * ss
    alpha = np.clip(0.5 - dist_p / 2.4, 0.0, 1.0)

    ny = (yy - yc) / np.maximum(1.0, half_h)
    shade = np.clip(0.62 - 0.25 * ny - 0.08 * t, 0.0, 1.0)
    col_r = 216.0 + 37.0 * shade
    col_g = 128.0 + 62.0 * shade
    col_b = 75.0 + 62.0 * shade
    edge = np.exp(-((dist_p + 1.4) ** 2) / 2.8)
    col_r -= 24.0 * edge
    col_g -= 28.0 * edge
    col_b -= 20.0 * edge

    arr[:, :, 0] = np.clip(col_r, 0, 255)
    arr[:, :, 1] = np.clip(col_g, 0, 255)
    arr[:, :, 2] = np.clip(col_b, 0, 255)
    arr[:, :, 3] = np.clip(alpha * 255.0, 0, 255)
    palm_img = Image.fromarray(arr.astype(np.uint8), "RGBA").resize((w, h), Image.Resampling.LANCZOS)

    thumb = draw_soft_finger(length=19.0, thickness=8.0, tip_taper=0.84, nail=True)
    thumb_angle = 32.0 if thumb_on_top else -32.0
    t_rot = thumb.rotate(thumb_angle, resample=Image.Resampling.BICUBIC, expand=True)
    ty = 66 if thumb_on_top else 94
    canvas.paste(t_rot, (64 - t_rot.width // 2, ty - t_rot.height // 2), t_rot)
    canvas = Image.alpha_composite(canvas, palm_img)

    if include_fingers:
        # Slight overlap (+0.8px thickness) ensures closed cover never lets a slit peek through
        if thumb_on_top:
            specs = [(22.0, 7.6, 90), (26.0, 8.1, 83), (28.5, 8.3, 76), (26.0, 8.1, 69)]
        else:
            specs = [(22.0, 7.6, 69), (26.0, 8.1, 75), (28.5, 8.3, 82), (26.0, 8.1, 89)]

        for flen, fthick, fy in specs:
            fimg = draw_soft_finger(length=flen, thickness=fthick, tip_taper=0.86, nail=True)
            canvas.paste(fimg, (72 - 16, fy - 20), fimg)

    return recolor_edge_decontaminate(canvas)


def build_peek_finger_parts() -> dict[str, Image.Image]:
    """Create modular dorsal finger parts aligned to bone 6-9's finger bones for PasswordPeek."""
    palm_only = draw_dorsal_hand_cover(thumb_on_top=False, include_fingers=False)
    idx = draw_soft_finger(length=26.0, thickness=8.1, tip_taper=0.86, nail=True)
    mid = draw_soft_finger(length=28.5, thickness=8.3, tip_taper=0.86, nail=True)
    ring = draw_soft_finger(length=26.0, thickness=8.1, tip_taper=0.86, nail=True)
    little = draw_soft_finger(length=22.0, thickness=7.6, tip_taper=0.86, nail=True)
    return {
        "Hand_R_Cover_Palm.png": palm_only,
        "Hand_R_Finger_Index.png": idx,
        "Hand_R_Finger_Middle.png": mid,
        "Hand_R_Finger_Ring.png": ring,
        "Hand_R_Finger_Little.png": little,
    }


def make_contact_sheet(parts: dict[str, Image.Image], out_path: Path) -> None:
    """Create a labeled grid preview of all generated parts for visual inspection."""
    cols = 4
    cell_w, cell_h = 220, 240
    rows = (len(parts) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * cell_h), (244, 246, 250, 255))
    draw = ImageDraw.Draw(sheet)

    for idx, (name, im) in enumerate(parts.items()):
        r, c = divmod(idx, cols)
        x0, y0 = c * cell_w, r * cell_h
        box = [x0 + 12, y0 + 28, x0 + cell_w - 12, y0 + cell_h - 12]
        draw.rectangle(box, fill=(224, 229, 238, 255), outline=(180, 190, 205, 255))
        scale = min((cell_w - 32) / im.width, (cell_h - 48) / im.height, 1.5)
        pw, ph = int(im.width * scale), int(im.height * scale)
        resized = im.resize((pw, ph), Image.Resampling.LANCZOS)
        px = x0 + (cell_w - pw) // 2
        py = y0 + 30 + (cell_h - 44 - ph) // 2
        sheet.paste(resized, (px, py), resized)
        draw.text((x0 + 14, y0 + 8), name.replace(".png", ""), fill=(25, 35, 50, 255))

    sheet.save(out_path)


def main() -> None:
    sleeve_l = build_clean_sleeve(RIVE_TOOLS / "Relaxed_Arm_Screen_Left.png", is_left_screen=True)
    sleeve_r = build_clean_sleeve(RIVE_TOOLS / "Relaxed_Arm_Screen_Right.png", is_left_screen=False)
    hand_l_rel, hand_r_rel = build_relaxed_hands()
    hand_l_palm = draw_palm_hand(thumb_on_bottom=True)
    hand_r_palm = draw_palm_hand(thumb_on_bottom=False)
    hand_l_cov = draw_dorsal_hand_cover(thumb_on_top=True, include_fingers=True)
    hand_r_cov = draw_dorsal_hand_cover(thumb_on_top=False, include_fingers=True)
    peek_parts = build_peek_finger_parts()

    outputs = {
        "Sleeve_ScreenL_Clean.png": sleeve_l,
        "Sleeve_ScreenR_Clean.png": sleeve_r,
        "Hand_ScreenL_Relaxed.png": hand_l_rel,
        "Hand_ScreenR_Relaxed.png": hand_r_rel,
        "Hand_ScreenL_Palm.png": hand_l_palm,
        "Hand_ScreenR_Palm.png": hand_r_palm,
        "Hand_ScreenL_Cover.png": hand_l_cov,
        "Hand_ScreenR_Cover.png": hand_r_cov,
        **peek_parts,
    }

    meta = {}
    for fname, im in outputs.items():
        p = OUT_DIR / fname
        im.save(p)
        meta[fname] = {"width": im.width, "height": im.height}

    with open(OUT_DIR / "manifest.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)

    make_contact_sheet(outputs, OUT_DIR / "contact_sheet_preview.png")
    print("Generated", len(outputs), "clean rig parts into", OUT_DIR)


if __name__ == "__main__":
    main()
