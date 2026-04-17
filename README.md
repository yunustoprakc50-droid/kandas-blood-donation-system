KANDAS - Emergency Blood Request System

📌 Overview

KANDAS is a mobile-based emergency blood request system designed to connect hospitals with nearby citizens in urgent situations.

This project was developed for public benefit, without any commercial intent.


🚀 Features

Emergency blood requests can be created by authorized personnel

Automatic push notifications to users in the same city

Requests expire automatically after 24 hours

Built-in limits to prevent spam and abuse

No personal data collection (KVKK compliant)

🔐 Security Approach

Role-based access system (Admin, Başhekim, Doctor)

Daily request limits per user

Login attempt restrictions

System-wide emergency lock mechanism

Firebase security rules enforced


👉 System Documentation (PDF)(https://github.com/yunustoprakc50-droid/kandas-blood-donation-system/blob/main/kandas.pdf)

👉 Security Rules
(https://github.com/yunustoprakc50-droid/kandas-blood-donation-system/blob/main/kandas_rules.txt)

⚠️ Disclaimer

This project is a prototype built for demonstration and improvement purposes.
Sensitive data and credentials have been removed.

🎯 Purpose

The goal of this system is to provide a structured alternative to informal blood request sharing methods (such as social media), and improve response speed in emergency situations.

Developed independently with a focus on real-world usability.

⚠️ Security Notice

This project is provided as a prototype.

Some security logic (such as validation and permissions) is simplified and partially handled on the client side.

Anyone who wants to use this system in production must implement:

Proper backend validation

Secure authentication mechanisms

Strict access control

The author is not responsible for misuse or insecure deployments.

🔒 Note

This repository contains a simplified and cleaned version of Firestore security rules.

Sensitive parts have been removed.
Developed by Yunus Toprakcı
