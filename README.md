# Decoupled Video Player

A Flutter application that demonstrates **Clean Architecture** and **Dependency Inversion** principles applied to video playback — decoupling UI from third-party packages through well-defined interfaces.

## The Problem

Most Flutter video player tutorials wire the `video_player` package directly into your widgets:

```dart
// ┌──────────────────┐
│  VideoScreen       │
│  StatefulWidget    │────────┐
│                    │         │  tightly coupled
│  build() {         │         │  to the package
│    VideoPlayer(    │         │
│      controller,   │         │
│    );              │         │
│  }                 │         │
└──────────────────┘         │
                             │
              ┌──────────────┘
              ▼
┌──────────────────────────┐
│ video_player_package     │
│ (external dependency)    │
└──────────────────────────┘
```

Tightly coupling your UI to a third-party library creates four problems:
1. **Testing becomes hard** — you can't mock playback state without launching the real player
2. **Refactoring is risky** — swapping `video_player` for another package means touching every widget
3. **UI and business logic are entangled** — the same controller is used both for rendering and for control
4. **State leaks** — `VideoPlayerController` exposes many internals your UI doesn't need

## The Solution: Clean Architecture

This project applies the **Dependency Inversion Principle** (the "D" in SOLID):

> *High-level modules should not depend on low-level modules. Both should depend on abstractions.*

### Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│                 UI Layer                        │
│    VideoPlayerView (StatefulWidget)             │
│    ┌───────────────────────────────────────┐    │
│    │  ValueListenableBuilder for controls   │    │
│    │  buildVideoWidget() from service       │    │
│    └───────────────────────────────────────┘    │
└────────────────────────┬────────────────────────┘
                         │ depends on
                         │ interface (not implementation)
                         ▼
┌─────────────────────────────────────────────────┐
│              Abstraction Layer                  │
│    CustomVideoPlayerService (abstract class)    │
│    ┌───────────────────────────────────────┐    │
│    │  ValueNotifier<bool> isPlaying        │    │
│    │  ValueNotifier<Duration> position     │    │
│    │  Future<void> play()                  │    │
│    │  Future<void> pause()                 │    │
│    │  Widget buildVideoWidget()            │    │
│    │  Future<void> dispose()               │    │
│    └───────────────────────────────────────┘    │
└────────────────────────┬────────────────────────┘
                         │ implements
                         ▼
┌─────────────────────────────────────────────────┐
│              Infrastructure Layer               │
│    VideoPlayerServiceImpl                      │
│    ┌───────────────────────────────────────┐    │
│    │  wraps: video_player package           │    │
│    │  bridges controller events to          │    │
│    │    ValueNotifiers                      │    │
│    │  adapts: third-party API → our API     │    │
│    └───────────────────────────────────────┘    │
└────────────────────────┬────────────────────────┘
                         │ uses
                         ▼
┌─────────────────────────────────────────────────┐
│           External Dependencies                 │
│    video_player package                         │
│    (unstable, changes, gets deprecated)          │
└─────────────────────────────────────────────────┘
```

The key insight: the arrow of dependency points **toward the abstraction**. The UI knows nothing about `video_player`. Only the service implementation does.

### Key Concepts

#### 1. Dependency Inversion

> *"Talk with infrastructure via interfaces, not directly."*

```dart
// ✅ The UI depends on an abstraction
class VideoPlayerView extends StatefulWidget {
  final CustomVideoPlayerService playerService;  // interface

// ❌ Never do this — UI depends on the concrete package controller
// class VideoPlayerView extends StatefulWidget {
//   final VideoPlayerController controller;  // concrete, external
```

#### 2. Adapter Pattern

The service implementation acts as an adapter between the `video_player` package's API and your clean interface:

```dart
class VideoPlayerServiceImpl implements CustomVideoPlayerService {
  // Adapter: bridges third-party controller → our ValueNotifiers
  pkg.VideoPlayerController? _controller;

  @override
  Future<void> initialize(String url) async {
    _controller = pkg.VideoPlayerController.networkUrl(Uri.parse(url));
    await _controller!.initialize();
    isInitialized.value = true;

    // Adapt the package's event system into reactive ValueNotifiers
    _controller!.addListener(() {
      isPlaying.value = _controller!.value.isPlaying;
      position.value  = _controller!.value.position;
    });
  }
}
```

#### 3. Dependency Injection

The service is constructed at the root (`main.dart`) and injected down the widget tree:

```dart
// Construction in main.dart — the "composition root"
MaterialApp(
  home: VideoPlayerView(
    playerService: VideoPlayerServiceImpl(),  // injected
    videoUrl: '...',
  ),
)
```

*(In a real app this would use a DI container like GetIt or Injectable. For this demo, simple constructor injection demonstrates the principle.)*

#### 4. Reactive State via ValueNotifier

The service exposes state as `ValueNotifier`s. The UI never polls — it subscribes:

```dart
// UI reacts automatically when state changes
ValueListenableBuilder<bool>(
  valueListenable: widget.playerService.isPlaying,
  builder: (context, isPlaying, _) {
    return IconButton(
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      onPressed: () => isPlaying
          ? widget.playerService.pause()
          : widget.playerService.play(),
    );
  },
)
```

#### 5. Separation of Concerns

| Layer | Responsibility | Knows About |
|-------|---------------|-------------|
| **UI** | Rendering, user interaction | Service interface only |
| **Service** | State orchestration, domain rules | Service interface contract |
| **Implementation** | Wrapping third-party SDK | `video_player` package |
| **Package** | Video rendering, decoding | Nothing |

## Getting Started

### Prerequisites

- Flutter SDK 3.12.0+
- An emulator or physical device

### Setup

```bash
# Clone the repository
git clone <repo-url>
cd decoupled_player_flutter

# Install dependencies
flutter pub get
```

### Run

```bash
# Android
flutter run -d android

# iOS
flutter run -d iphone

# Web
flutter run -d chrome

# macOS
flutter run -d macos
```

## Project Structure

```
lib/
├── main.dart                          # Composition root — wires everything together
├── services/
│   ├── video_player_service.dart      # Abstraction — the interface UI depends on
│   └── video_player_service_impl.dart # Infrastructure — adapts video_player package
└── views/
    └── video_player_view.dart         # UI — consumes service interface, zero package knowledge
```

## How This Helps

| Without Decoupling | With Clean Architecture |
|--------------------|------------------------|
| Every widget that plays video needs a `VideoPlayerController` | Any widget can use any `CustomVideoPlayerService` implementation |
| Can't unit test UI without mocking Flutter framework + platform channels | UI is pure Dart — mock `CustomVideoPlayerService` in tests |
| Swapping the player SDK = rewriting all widgets | Swapping the player SDK = rewriting one file |
| UI code mixes rendering logic with control logic | UI code owns rendering; service code owns state |

## What's Next

This demo intentionally keeps the UI minimal (one play/pause button). To extend it, you would add controls **only through the service interface**:

- Seek bar → `seekTo(Duration)` + `position` notifier
- Volume control → new method on the interface
- Subtitle support → new method on the interface
- Different player backend (e.g., `better_player`) → new `CustomVideoPlayerService` implementation, zero UI changes

The goal is that **the only file that changes when you swap players is the `*_service_impl.dart` file**.

## License

Free to use as a reference and starting point for your own projects.
