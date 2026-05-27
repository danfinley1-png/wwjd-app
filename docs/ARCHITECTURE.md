# WWJD Catholic Dialog App - ARCHITECTURE
## Overview
A cross-platform Flutter application delivering faithful Catholic guidance using the "What Would Jesus Do?" framework, powered by xAI/Grok with strong theological guardrails.
## Current File Structure (as of May 27, 2026)

wwjd_app/
├── docs/                          # Living documentation (critical for context)
│   ├── REQUIREMENTS.md
│   ├── DEVELOPMENT_WORKFLOW.md
│   ├── ARCHITECTURE.md
│   └── PROJECT_CONTEXT.md
├── lib/                           # Main source code
│   ├── main.dart                  # Entry point (current main screen)
│   └── mainbackup.txt
├── assets/                        # Images and static resources
├── android/, ios/, web/, windows/ # Platform-specific folders
├── firebase/                      # Firebase configuration
├── test/                          # Tests
├── .agents/                       # Grok agent skills and references
├── pubspec.yaml
├── pubspec.lock
└── README.md

## Tech Stack
- **Frontend**: Flutter (Dart) — Multi-platform (Mobile, Web, Desktop)
- **AI Engine**: xAI Grok API
- **Backend**: Firebase
- **Design**: Catholic-inspired (maroon/gold, winged cross logo)

## Key Principles
- Single codebase for App + Public Website (Flutter Web)
- Strong separation between UI, Business Logic, and Theology Guardrails
- docs/ folder is the **Single Source of Truth** for project memory

## Current State
- Working UI with left sidebar + structured WWJD responses (see screenshot)
- Recent challenges: Code loss after long sessions, Flutter recompilation issues
- GitHub repo active: https://github.com/danfinley1-png/wwjd-app

## High-Level Flow
User → Flutter UI → WWJD Response Engine → Theology Guardrail → Grok API → Firebase

## Future Improvements
- Modular feature folders (lib/features/chat/, lib/features/journal/, etc.)
- Stronger offline Catholic content
- Better state management
