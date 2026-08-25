/// UI-facing state of an exercise's instructional video, derived from the
/// latest `ExerciseVideo` row for that exercise (never stored directly).
sealed class ExerciseVideoState {
  const ExerciseVideoState();
}

/// No provider configured yet (real-provider selection lands in M8).
class NotConfigured extends ExerciseVideoState {
  const NotConfigured();
}

/// Provider available, no video generated yet (or a previous failure was
/// dismissed).
class Idle extends ExerciseVideoState {
  const Idle();
}

class Generating extends ExerciseVideoState {
  const Generating();
}

class Ready extends ExerciseVideoState {
  const Ready(this.filePath);

  final String filePath;
}

class Failed extends ExerciseVideoState {
  const Failed(this.message);

  final String message;
}
