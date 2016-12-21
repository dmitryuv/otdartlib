part of otdartlib.atext_changeset;

class ChangesetComposer extends _ChangesetComposerBase implements OperationComposer<Changeset> {
  Changeset _cs;

  ChangesetComposer(this._cs) : super(_cs.iterator, OpComponent.REMOVE);

  Changeset finish() {
    _finalizeIterator();

    return new Changeset(_out, _cs._oldLen, author: _cs._author, newLen: _cs._oldLen + _out.deltaLen);
  }
}