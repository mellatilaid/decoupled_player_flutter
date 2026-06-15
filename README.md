# Decoupled Video Player

A Flutter project demonstrating how to decouple your app from third-party packages using **Dependency Inversion** and the **Adapter** pattern.

The `video_player` package is one concrete example. The same technique applies to Stripe, Firebase, Google Maps, analytics tools, or any third-party package you don't control.

## The Problem

Nearly every Flutter tutorial wires third-party packages directly into your widgets:

```dart
// The pattern you see everywhere — for video, payments, maps, auth, analytics...

class VideoScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse('https://example.com/video.mp4'),
    );  // ← direct dependency on package type
    return Column(children: [
      VideoPlayer(controller),
      PlayPauseButton(controller),
      SeekBar(controller),
    ]);
  }
}
```

This creates **inversion of control** — your high-level business logic depending on low-level, unstable external details:

```
┌──────────────────┐
│  Your Screen     │
│  (business logic) │────────┐
│                  │         │  ← dependency FLOWS the wrong way
│  VideoPlayer(    │         │     INTO your code
│    controller     │         │
│  )               │         │
└──────────────────┘         │
                             │
              ┌──────────────┘
              ▼
┌──────────────────────────┐
│  video_player package    │
│  (unstable, changes,     │
│   gets deprecated)       │
└──────────────────────────┘
```

The problems multiply as your app grows:

1. **Testing is painful** — you can't unit-test screens without launching real platform channels
2. **Swapping packages costs everything** — replacing `video_player` with `better_player` means rewriting every screen
3. **State leaks into your UI** — the SDK exposes raw internals your screens don't need and shouldn't touch
4. **No clear ownership** — who handles errors, retries, loading states? The package decides
5. **No portability** — your screens are no longer reusable in a different context

> Any third-party package you care about — video players, payment gateways, map providers, auth SDKs, analytics tools, databases — can be decoupled the same way. This repo uses a video player because it's visual and relatable, but the architecture is **100% generic**.

## The Solution — Dependency Inversion

This project applies the **Dependency Inversion Principle** (the "D" in SOLID):

> High-level modules should not depend on low-level modules. Both should depend on abstractions. Abstractions should not depend on details. Details should depend on abstractions.

Translated into practice:

- You define an **interface** that describes **what** your app needs
- An **adapter** in the infrastructure layer implements that interface and wraps the package
- The dependency arrows point **towards** the interface

```dart
// ✅ Your screens depend ONLY on an interface
abstract class CustomVideoPlayerService {
  Future<void> play();
  Future<void> pause();
  Widget buildVideoWidget();
}

// ❌ Never do this — your screen knows about the package
// class VideoPlayerView extends StatefulWidget {
//   final VideoPlayerController controller;  // package type, not yours
//   // ...
// }
```

## General Architecture — Works for Any Third-Party

This pattern applies identically to payments, maps, auth, analytics, databases, or **any** external service:

```
┌─────────────────────────────────────────────────┐
│                  YOUR CODE                      │
│    (Screens, Widgets, Business Logic)           │
│  ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─   │
│  "I call service methods. That's all."        │
└────────────────────────┬────────────────────────┘
                         │ depends on
                         │ abstract interface
                         ▼
┌─────────────────────────────────────────────────┐
│              ABSTRACTION LAYER                  │
│     WHAT your app needs — not HOW             │
│                                                 │
│   CustomVideoPlayerService  abstract class     │
│   PaymentGateway         abstract class        │
│   MapService             abstract class        │
│   AuthProvider           abstract class        │
│   StorageService         abstract class        │
│                                                 │
│   These describe domain goals.                  │
│   They NEVER import pub packages.               │
└────────────────────────┬────────────────────────┘
                         │ implements
                         ▼
┌─────────────────────────────────────────────────┐
│         INFRASTRUCTURE / ADAPTER LAYER          │
│    Bridging SDKs into your interfaces           │
│                                                 │
│   VideoPlayerServiceImpl   wraps                │
│      video_player package                       │
│   StripePaymentImpl          wraps              │
│      stripe_payment package                     │
│   GoogleMapsImpl         wraps                  │
│      google_maps_flutter                        │
│   FirebaseAuthImpl       wraps                  │
│      firebase_auth                              │
│                                                 │
│   These are the ONLY files that know about      │
│   external packages.                            │
└────────────────────────┬────────────────────────┘
                         │ uses
                         ▼
┌─────────────────────────────────────────────────┐
│         EXTERNAL DEPENDENCIES                   │
│    (packages you don't control)                 │
└─────────────────────────────────────────────────┘
```

## Concrete Examples — Beyond This Repo

| Third-Party Service  | Interface Contract                         | SDK Your Adapter Wraps            |
| ---------------------| ------------------------------------------ | --------------------------------- |
| Video Player         | `play(), pause(), seekTo()`                | `video_player`                    |
| Payment Gateway      | `charge(amount, currency), refund()`       | `stripe_payment`, `flutter_stripe`|
| Maps                 | `showPosition(lat, lng), zoomLevel()`      | `google_maps_flutter`             |
| Authentication       | `signIn(provider), sessionState()`         | `firebase_auth`, `go_router`      |
| Analytics            | `trackEvent(name, props)`                  | `firebase_analytics`, `mixpanel`  |
| File Storage         | `upload(path, bytes), read(path)`          | `cloud_firestore`, `hive`         |
| Push Notifications   | `register(), handleMessage()`              | `firebase_messaging`              |

For each of these, your screens, tests, and business logic depend only on the abstract class. Swapping providers means rewriting a single adapter file — nothing else changes.

## How to Decouple — Step by Step

Applying this to any third-party package:

### Step 1 — Define the interface

Look at how you currently use the package. What methods do you call? What state do you read? Write those down as an abstract interface:

```dart
abstract class VideoPlayerService {
  ValueNotifier<bool> get isPlaying;
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration p);
  Widget buildVideoWidget();
  Future<void> dispose();
}
```

*This interface lives in your domain layer.* It has zero knowledge of the package.

### Step 2 — Write the adapter

Create a class that implements the interface and wraps the SDK:

```dart
class VideoPlayerServiceImpl implements VideoPlayerService {
  // Only this file imports video_player
  VideoPlayerController? _ctrl;

  @override
  Future<void> initialize(String url) async {
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    await _ctrl!.initialize();
    _ctrl!.addListener(() {
      isPlaying.value = _ctrl!.value.isPlaying;
      position.value  = _ctrl!.value.position;
    });
  }

  @override
  Future<void> play() => _ctrl?.play();

  @override
  Widget buildVideoWidget() => VideoPlayer(_ctrl!);

  // ...
}
```

The adapter is the **only file** that knows the package exists.

### Step 3 — Inject at the top

Construct your implementation and pass the interface down:

```dart
MaterialApp(
  home: VideoPlayerView(
    playerService: VideoPlayerServiceImpl(),  // interface type
    videoUrl: 'https://example.com/video.mp4',
  ),
)
```

Your screens never see `VideoPlayerServiceImpl`. They only see `VideoPlayerService`.

## Key Concepts

### Dependency Inversion

High-level modules (your screens) depend on abstractions, not concrete implementations. The concrete adapter is a detail that can change without affecting the screens.

### Adapter Pattern

The adapter sits between your interface and the external SDK. It translates the SDK's API into your clean interface — handling initialization, event translation, error mapping, and lifecycle management.

### Dependency Injection

Services are constructed at the root and injected down the widget tree. The screens receive their dependencies through constructors rather than creating them internally.

### Composition Root

`main.dart` is the composition root — the single place where concrete implementations are wired to interfaces. Changing the backing package means changing just this one place.

## Project Structure

```
lib/
├── main.dart                              # Composition root — wires interface → impl
├── services/
│   ├── video_player_service.dart          # Abstraction — interface, ZERO package imports
│   └── video_player_service_impl.dart     # Adapter — wraps video_player package
└── views/
    └── video_player_view.dart             # UI — only knows about the interface
```

## Setup

```bash
flutter pub get
flutter run
```

## Extending This Pattern

To add a new service (payments, maps, auth, analytics...) follow the same three files:

1. New interface in `services/`
2. New implementation in `services/`
3. Wire it in `main.dart` and inject it

Zero existing files need to change. That's the power of the pattern.
