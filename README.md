# ReVault

**ReVault** is a secure, offline-first password manager built with Flutter that helps you organize and protect your credentials. It stores passwords locally using AES encryption, secures access with a PIN and biometric authentication, and supports encrypted cloud backups to Google Drive.

> Your passwords. Your device. Your control.

---

## Features

### Security
- AES-256 encrypted password storage
- 4-digit PIN protection
- Fingerprint / Face ID authentication
- Secure password encryption and decryption
- Offline-first architecture

### Organization
- Create nested folders to organize accounts
- Store credentials for websites and applications
- Edit or delete folders and accounts
- Hierarchical vault structure

### Backup & Restore
- End-to-end encrypted backups
- Google Drive integration
- Password-protected backup files
- One-click restore from encrypted backups

### User Experience
- Modern Material Design UI
- Dark theme
- Swipe actions for quick editing and deletion
- Fast local database using Hive

---

## Tech Stack

### Frontend
- Flutter
- Dart

### Local Storage
- Hive Database
- SharedPreferences

### Security
- AES Encryption
- SHA-256 Hashing
- Local Authentication (Fingerprint / Face ID)

### Cloud
- Google Drive API
- Google Sign-In

---

## Dependencies

- hive
- hive_flutter
- encrypt
- crypto
- local_auth
- google_sign_in
- googleapis
- shared_preferences
- flutter_slidable
- circular_menu

---

## Getting Started

### Clone the repository

```bash
git clone https://github.com/unethicalMonk/revault
cd ReVault
```

### Install dependencies

```bash
flutter pub get
```

### Run the application

```bash
flutter run
```

---

## Project Structure

```
lib/
│
├── models/
├── screens/
├── services/
├── widgets/
├── main.dart
```

---

## Security Note

ReVault is designed with privacy in mind:

- Passwords are never stored in plain text.
- All sensitive data is encrypted before being saved locally.
- Backups are encrypted before uploading to Google Drive.
- Authentication is handled locally using PIN or biometrics.

---

## Future Improvements

- Password generator
- Password strength analysis
- Autofill support
- Secure notes
- TOTP / 2FA support
- Search functionality
- Import & Export from popular password managers
- Cross-device synchronization

---

## Contributing

Contributions are welcome!

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a Pull Request

---

## License

This project is licensed under the MIT License.

---

## Support

If you found this project helpful, please consider giving it a ⭐ on GitHub!
