// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(noteDetail)
final noteDetailProvider = NoteDetailFamily._();

final class NoteDetailProvider
    extends
        $FunctionalProvider<
          AsyncValue<NoteModel>,
          NoteModel,
          FutureOr<NoteModel>
        >
    with $FutureModifier<NoteModel>, $FutureProvider<NoteModel> {
  NoteDetailProvider._({
    required NoteDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'noteDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$noteDetailHash();

  @override
  String toString() {
    return r'noteDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<NoteModel> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<NoteModel> create(Ref ref) {
    final argument = this.argument as String;
    return noteDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is NoteDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$noteDetailHash() => r'bdec2f97a88cb272ca580538ef38f507818a8970';

final class NoteDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<NoteModel>, String> {
  NoteDetailFamily._()
    : super(
        retry: null,
        name: r'noteDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  NoteDetailProvider call(String noteId) =>
      NoteDetailProvider._(argument: noteId, from: this);

  @override
  String toString() => r'noteDetailProvider';
}

@ProviderFor(NotesController)
final notesControllerProvider = NotesControllerProvider._();

final class NotesControllerProvider
    extends $AsyncNotifierProvider<NotesController, List<NoteModel>> {
  NotesControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notesControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notesControllerHash();

  @$internal
  @override
  NotesController create() => NotesController();
}

String _$notesControllerHash() => r'74c05f4ebcf8fcda4d7f1740cd4fac7e2a046ec8';

abstract class _$NotesController extends $AsyncNotifier<List<NoteModel>> {
  FutureOr<List<NoteModel>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<NoteModel>>, List<NoteModel>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<NoteModel>>, List<NoteModel>>,
              AsyncValue<List<NoteModel>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
