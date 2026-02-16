# Sovereign Novel Reading Ecosystem

A personal novel reading application that enables sovereign control over content, translation, and data. This cross-platform app combines Flutter development, PocketBase backend infrastructure, and local LLM-powered translation using LM Studio—all hosted on personal hardware with zero cloud dependencies.

## 🎯 Executive Summary

This project creates a complete ecosystem for managing, translating, and reading Chinese and Japanese novels privately. The system architecture prioritizes:

- **Sovereignty**: All data stays on your personal hardware
- **Privacy**: Translation powered by local LLMs (no cloud dependencies)
- **Accessibility**: Cross-platform support (Windows, Android, iOS)
- **Offline-First**: Works seamlessly with or without network connectivity
- **Security**: Secure access via Tailscale mesh networking

## ✨ Key Features

### Content Management

- Manual novel series curation with cover artwork
- Chapter organization with progress tracking
- Support for Chinese and Japanese source materials
- Real-time translation status monitoring

### Translation Engine

- Local LLM integration via LM Studio (no API costs or privacy concerns)
- Intelligent text chunking with context preservation
- Support for multiple models (Gemma-2, Mistral-Nemo)
- Background translation on desktop and mobile
- Translation history and quality ratings

### Reader Interface

- Paginated text display with smooth scrolling
- Customizable themes (Light, Dark, Sepia)
- Adjustable fonts and sizes
- Chapter navigation and reading progress persistence
- Swipe gestures for chapter navigation

### Offline Capabilities

- Local database caching via Drift
- Download chapters for offline reading
- Intelligent sync when connectivity restored
- Conflict resolution across devices

### Network Access

- Tailscale mesh networking for secure cross-device access
- VLAN isolation for privacy
- No port forwarding required

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────┐
│              Flutter Application                     │
│  (Windows Desktop, Android, iOS)                     │
│  - Dashboard (Series/Chapter Management)            │
│  - Reader (Paginated Display, Themes)               │
│  - Settings (Customization, Cache Management)       │
└────────────────┬────────────────────────────────────┘
                 │ MVVM Pattern + Provider State Mgmt
                 │
     ┌───────────┴──────────────┬────────────────┐
     │                          │                │
┌────▼──────────┐      ┌────────▼────────┐   ┌──▼─────────────┐
│  PocketBase   │ ────▶│ Tailscale VPN   │◀──│  LM Studio     │
│  (SQLite)     │      │ (Mesh Network)  │   │  (Local LLM)   │
│  - Series     │      └─────────────────┘   │  - Gemma-2     │
│  - Chapters   │                            │  - Mistral     │
│  - Translations│                           │  - Custom      │
└───────────────┘                            └────────────────┘
```

**Communication Flow:**

1. Flutter app connects to PocketBase via Tailscale IP
2. User adds chapters with source text
3. Translation triggered → Flutter calls LM Studio API via Tailscale
4. LM Studio processes in chunks with 10-20% overlap
5. Translated text stored in PocketBase
6. Mobile devices download and cache locally (Drift database)

## 📋 Tech Stack

### Frontend

- **Flutter**: Cross-platform UI framework
- **Provider**: State management
- **Drift**: Local database with type-safe queries
- **workmanager**: Background task execution

### Backend

- **PocketBase**: Lightweight backend with SQLite, built-in API, real-time subscriptions
- **LM Studio**: Local LLM server (GGUF quantized models)
- **Tailscale**: Secure mesh networking

### Key Dependencies

```yaml
pocketbase: ^0.18.0
pocketbase_drift: latest
provider: ^6.0.0
http: ^1.0.0
workmanager: ^0.5.0
shared_preferences: ^2.0.0
google_fonts: ^6.0.0
connectivity_plus: ^5.0.0
```

## 🚀 Project Phases

| Phase                             | Duration  | Key Deliverables                                      |
| --------------------------------- | --------- | ----------------------------------------------------- |
| 1. Development Environment Setup  | 1-2 weeks | Flutter, PocketBase, LM Studio, Tailscale configured  |
| 2. Database Schema & Backend      | 1 week    | PocketBase collections, validation rules, sample data |
| 3. Flutter Frontend Architecture  | 2-3 weeks | MVVM app with Dashboard and Reader UI                 |
| 4. Translation Engine Integration | 2 weeks   | LM Studio API, chunking, background tasks             |
| 5. Offline-First Architecture     | 1-2 weeks | Drift database, sync mechanism, offline reading       |
| 6. Mobile Deployment & Testing    | 1-2 weeks | Android APK, iOS build, testing, documentation        |

**Total Estimated Timeline:** 8-12 weeks (part-time, 10-15 hours/week)

## 📂 Project Structure

```
lib/
├── models/              # Data models (Series, Chapter, Translation, Settings)
├── viewmodels/          # Business logic (ViewModels for CRUD, state)
├── views/
│   ├── dashboard/       # Series grid, chapter list, add/edit forms
│   └── reader/          # Paginated text display, customization settings
├── services/
│   ├── pocketbase_service.dart    # Backend API integration
│   └── translation_service.dart   # LM Studio integration
├── utils/               # Helper functions and constants
└── main.dart
```

## 🛠️ Getting Started

### Prerequisites

**Hardware Requirements:**

- PC with 16GB+ RAM (minimum)
- GPU with 8GB+ VRAM recommended (for LLMs)
- Secondary devices for testing (Android phone or iOS device)

**Software Requirements:**

- Flutter SDK (latest stable)
- Visual Studio 2022 (with C++ Development tools)
- Android Studio or Xcode (for mobile development)
- PocketBase binary
- LM Studio installed
- Tailscale account

### Phase 1: Development Environment Setup

1. **Install Flutter**

   ```bash
   flutter doctor
   # Resolve all issues reported
   ```

2. **Configure Desktop Development**
   - Install Visual Studio 2022 with C++ Desktop Development workload
   - Configure Windows SDK and build tools

3. **Setup Android/iOS**
   - Android: Install Android Studio with SDK 33+
   - iOS: Install Xcode (Mac required) and configure provisioning profiles

4. **Install PocketBase**
   - Download from [pocketbase.io](https://pocketbase.io)
   - Extract to project directory
   - Set up Windows Task Scheduler for automatic startup

5. **Install LM Studio**
   - Download from lmstudio.ai
   - Download a model (e.g., Gemma-2 9B, Mistral-Nemo 12B)
   - Configure server on 0.0.0.0 port 1234

6. **Setup Tailscale**
   - Create account at tailscale.com
   - Install on PC and all devices
   - Verify mesh connectivity

## 📊 Database Schema

### Series Collection

- `title` (Text, Required): Novel series title
- `author` (Text, Optional): Original author
- `cover_image` (File, Optional): Cover art (jpg/png, max 2MB)
- `source_language` (Select): Chinese or Japanese
- `description` (Text, Optional): Series synopsis
- `status` (Select): Active, Completed, or Paused
- `created`, `updated` (Auto): Timestamps

### Chapters Collection

- `series_id` (Relation, Required): Link to Series
- `chapter_number` (Number, Required): Sequential identifier
- `title` (Text, Optional): Chapter title
- `source_text` (Text, Required): Raw source content
- `word_count` (Number, Auto): Character count
- `translation_status` (Select): Pending, Processing, Completed, or Failed
- `created`, `updated` (Auto): Timestamps

### Translations Collection

- `chapter_id` (Relation, Required): Link to Chapter
- `translated_text` (Text, Required): English translation
- `model_used` (Text, Required): LLM model identifier
- `translation_date` (Auto): Completion timestamp
- `quality_rating` (Number, Optional): User rating 1-5
- `notes` (Text, Optional): Translation notes

**Indexes:**

- Chapters: `(series_id, chapter_number)` for fast lookups
- Translations: `chapter_id` for join performance

## 🤖 Translation Engine

### Text Chunking Strategy

- Split source text into 1024-2048 token segments
- 10-20% overlap between chunks to preserve context
- Split on sentence boundaries (full-width CJK punctuation)
- Post-process to remove duplicate sentences in overlaps

### Recommended Models

| Model            | Size       | VRAM         | Best For            |
| ---------------- | ---------- | ------------ | ------------------- |
| Gemma-2 9B       | 9B params  | 6-8GB (Q4)   | Cultural nuance     |
| Gemma-2 27B      | 27B params | 16-24GB (Q4) | Highest quality     |
| Mistral-Nemo 12B | 12B params | 8-10GB (Q5)  | Format preservation |

**Quantization Guidelines:**

- 8GB VRAM: Q4_K_M for 9B-12B models
- 12GB VRAM: Q5_K_M or Q6_K for higher quality
- 16GB+ VRAM: Q8_0 or FP16 for 12B models

### Example System Prompt

```
You are a professional literary translator specializing in Chinese/Japanese
to English translation. Translate the following text while preserving:
1. Narrative tone and style
2. Cultural context and idioms
3. Character voice consistency
4. Paragraph structure

Provide only the translation without commentary.
```

## 🔄 Offline-First Architecture

### Sync Strategy

- **Cache-First**: Read from local database, sync in background
- **Write-Local**: Save to local immediately, queue sync for later
- **Download Trigger**: Manual per-chapter or bulk series download
- **Conflict Resolution**: Timestamp-based last-write-wins with remote priority for metadata

### Network Status

- Display offline indicator in UI when disconnected
- Automatically resume sync when connectivity restored
- Disable translation triggers when offline

### Cache Management

- Configurable storage limit (default 500MB)
- Manual cache clearing with confirmation
- Selective deletion per series
- LRU eviction when threshold exceeded

## ✅ Success Criteria

| Phase | Gate                                                                        |
| ----- | --------------------------------------------------------------------------- |
| 1     | flutter doctor all green; PocketBase accessible; LM Studio responds <5s     |
| 2     | Schema validated; Referential integrity enforced; Can create series via API |
| 3     | App compiles on all platforms; CRUD works; Reader displays with themes      |
| 4     | Translate 1000+ char chapter <10 min; Quality passes review; No crashes     |
| 5     | Read offline; Sync works online; Cache management functional                |
| 6     | APK/iOS install; All tests pass; Performance benchmarks met                 |

## ⚠️ Risk Management

| Risk                       | Probability | Mitigation                                            |
| -------------------------- | ----------- | ----------------------------------------------------- |
| Insufficient VRAM          | Medium      | Test Q4 quantizations; Consider cloud GPU fallback    |
| Translation quality issues | Medium      | Enable re-translation; Test multiple models           |
| Background tasks killed    | High        | Implement checkpointing; Prefer desktop for batch     |
| Tailscale issues           | Low         | Document troubleshooting; Test before major tasks     |
| iOS signing complexity     | Medium      | Prioritize Android; Budget Apple Developer setup time |

## 📖 Usage Workflow

1. **Add Series**: Dashboard → "New Series" → Enter title, author, language, upload cover
2. **Add Chapters**: Select series → "Add Chapter" → Paste source text → Save
3. **Translate**: Click "Translate" on chapter → LM Studio processes → View progress
4. **Read**: Select translated chapter → Customize theme/font → Read with navigation
5. **Offline**: Download chapters → Enable airplane mode → Continue reading
6. **Sync**: Reconnect to network → Changes sync automatically

## 🔒 Security & Privacy

- All data stored locally on your PC and synced to your devices only
- No cloud services involved in translation or content storage
- Tailscale provides encrypted mesh networking
- Authentication required for PocketBase API access
- LM Studio runs locally—your content never leaves your hardware

## 📝 Development Guidelines

- Follow MVVM architecture strictly
- Use Provider for state management
- Implement comprehensive error handling
- Add logging for translation processes
- Test on all platforms before major commits
- Document any deviations from this plan

## 🐛 Troubleshooting

**PocketBase not accessible:**

- Verify it's running: Check Windows Task Scheduler
- Confirm Tailscale VPN is connected
- Check firewall allowing port 8090

**LM Studio API errors:**

- Ensure LM Studio is serving on 0.0.0.0:1234
- Test with curl: `curl http://localhost:1234/v1/models`
- Check available VRAM and model quantization

**Translation timeouts:**

- Increase timeout in `translation_service.dart`
- Consider smaller model or higher quantization
- Check chunk size (may be too large)

**Offline sync conflicts:**

- Timestamp-based resolution prioritizes remote data for metadata
- User can manually delete local chapters and re-download
- Check logs for conflict details

## 📚 Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [PocketBase Documentation](https://pocketbase.io/docs)
- [LM Studio](https://lmstudio.ai)
- [Tailscale Documentation](https://tailscale.com/kb)
- [Drift Database](https://drift.simonbinder.eu)

## 📄 Document Versions

- **v1.0**: Initial implementation plan and architecture (Feb 2026)

---

**Project Status:** Planning Phase (Development Environment Setup in progress)
