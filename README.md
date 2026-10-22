# Random QR

Flutter app with a built-in list of QR codes, each pointing to a photo on your own server.
The "Случайный" button shows a random QR fullscreen (max brightness, screen stays on);
someone scans it with their phone camera and the photo opens in the browser.
The photo can also be previewed under the QR.

Photos are served by Apache at `https://<domain>/p/<slug>.jpg`. Slugs are random,
so photos cannot be found without the QR code.

## 1. Server (once)

Needs Apache with `mod_ssl`, `mod_rewrite`, `mod_headers` and certbot, ports 80/443 open.
No domain? Use sslip.io: `photos.<public-ip>.sslip.io`.

```sh
scp -r server <ssh-host>:random_qr-server
ssh -t <ssh-host> 'cd random_qr-server && sudo sh setup-photos.sh <domain>'
```

`setup-photos.sh` creates `/var/www/photos/p`, adds vhosts `zz-photos` (HTTP, ACME only)
and `zz-photos-ssl`, and issues a separate Let's Encrypt certificate with
`certbot certonly --webroot`. Certbot does not edit Apache config, other sites and
their certificates are untouched; every reload is guarded by `apache2ctl configtest`.

## 2. Photos -> QR list

```sh
cp tools/config.example.json tools/config.json   # set base_url and ssh host
pip install Pillow pillow-heif qrcode            # optional but recommended
cp ~/my_photos/*.jpg tools/photos/
python3 tools/prepare.py
```

- Photos are resized to 2000px, renamed to random slugs and uploaded via rsync.
- `app/assets/qr_list.json` is regenerated; the title is the original file name.
- `tools/mapping.json` keeps file -> slug; do not delete it, or URLs change.
- `--export-png` additionally writes printable QR images to `tools/out/`.

`config.json`, `mapping.json`, `qr_list.json` and the photos are gitignored:
the slugs are what keeps the photos private, so never commit them.

Check: `curl -I https://<domain>/p/<slug>.jpg` -> 200, `curl -I https://<domain>/p/` -> 403.

## 3. App

```sh
cd app
flutter test
flutter run                 # device/emulator
flutter build apk --release # build/app/outputs/flutter-apk/app-release.apk
```

`assets/qr_list.json` is required for the build. To try the app without a server:
`cp assets/qr_list.example.json assets/qr_list.json`.
After changing photos, re-run `prepare.py` and rebuild the app.
