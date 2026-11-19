# Visual Verification & Screenshot Guide

This guide specifies the capture criteria and checklist for generating release media and documentation screenshots for the **Live Event Photo Slideshow Platform**.

---

## 1. Setup Instructions for Screenshot Generation

1. **Start the Backend API**:
   ```powershell
   cd backend
   .\venv\Scripts\Activate.ps1
   python main.py
   ```
2. **Launch the Flutter Web Client**:
   ```powershell
   cd frontend
   flutter run -d chrome --web-port 3000
   ```
3. **Seed Demo Data** (Optional for full queues):
   Run test suites to generate sample photos, or manually submit 3-4 event photos via the visitor portal.

---

## 2. Screenshot Specifications Matrix

| Screen Name | Target Route | Target Viewport | Theme / State | Checklist Item |
|---|---|---|---|---|
| **1. Welcome Screen** | `/` | Mobile (390 x 844) | Dark Theme | Hero logo, event subtitle, "Get Started" CTA, and admin link visible. |
| **2. Visitor Registration** | `/visitor/register` | Mobile (390 x 844) | Dark Theme | Name & email input fields with validation hints. |
| **3. Photo Upload with Consent** | `/visitor/upload` | Mobile (390 x 844) | Dark Theme | Image thumbnail previews, removal chips, explicit consent agreement checkbox (checked). |
| **4. My Photos History** | `/visitor/photos` | Mobile (390 x 844) | Dark Theme | Uploaded photos displaying status chips (Pending, Approved, Rejected) with "Delete" buttons. |
| **5. Admin Login** | `/admin/login` | Desktop (1920 x 1080) | Dark Theme | Username/password form with secure input masking. |
| **6. Admin Dashboard** | `/admin/dashboard` | Desktop (1920 x 1080) | Dark Theme | Metric summary cards (Total, Pending, Approved, Rejected, Visitors) and quick navigation cards. |
| **7. Photo Moderation Queue** | `/admin/moderation` | Desktop (1920 x 1080) | Dark Theme | Tabbed view (`Pending`, `Approved`, `Rejected`), visitor name/email attribution, consent verification badge, approve/reject buttons. |
| **8. Slideshow Settings** | `/admin/settings` | Desktop (1920 x 1080) | Dark Theme | Slide duration slider, transition dropdown, QR code toggle, and public portal URL field. |
| **9. Smart TV Active Slideshow** | `/display` | Landscape TV (1920 x 1080) | Ambient Cinema | Full-screen photo, subtle visitor name overlay at bottom-left, scan QR code card at bottom-right. |
| **10. Smart TV Empty Queue State** | `/display` | Landscape TV (1920 x 1080) | Ambient Cinema | Central empty state card, large scannable QR code, invitation instructions, public URL label. |

---

## 3. Image Formatting Guidelines for Repository Assets

- **Directory**: `docs/screenshots/`
- **Format**: PNG (lossless compression)
- **Naming Convention**:
  - `01_welcome_screen.png`
  - `02_visitor_registration.png`
  - `03_photo_upload_consent.png`
  - `04_my_photos_history.png`
  - `05_admin_login.png`
  - `06_admin_dashboard.png`
  - `07_photo_moderation.png`
  - `08_slideshow_settings.png`
  - `09_smart_tv_active.png`
  - `10_smart_tv_empty_qr.png`
