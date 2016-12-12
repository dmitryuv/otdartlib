part of otdartlib.atext_changeset;

class Position {
  final int ch;
  final int line;
  
  const Position([this.ch = 0, this.line = 0]);
  
  /**
   * Returns true if current position is before other position
   */
  bool before(Position other) => (line < other.line) || (line == other.line && ch < other.ch);

  int get hashCode => hash2(ch, line);
  
  bool operator==(other) => other is Position && line == other.line && ch == other.ch;

  /**
   * Adding lines does not alter char position in new line
   */
  Position add(int chars, int lines) {
    if(lines != 0) {
      return new Position(ch, line + lines);
    } else {
      return new Position(ch + chars, line);
    }
  }

  /**
   * Unlike adding, advance uses changeset logic to advance between lines
   * i.e. moving to next line resets char position
   */
  Position advance(int chars, int lines) {
    var p = add(chars, lines);
    if(lines != 0) {
      return new Position(0, p.line);
    }
    return p;
  }
  
  /**
   * Subtracts component chars or lines from position. Char position on this line should not be affected
   * if we're removing other linesэ
   */
  Position subtract(int chars, int lines) {
    if(lines != 0) {
      return new Position(ch, line - lines);
    } else {
      return new Position(ch - chars, line);
    }
  }


  /**
   * Transform single position by incoming operation. if operation is insert and side=='left',
   * cursor is pushed before the insert, overwise it's after the insert
   */
  Position transform(Changeset op, String side) {
    if(side != 'left' && side != 'right') {
      throw new Exception('side should be \'left\' or \'right\'');
    }

    var res = this;
    // iteration cursor
    var c = new Position();

    op.any((op) {
      if(op.isInsert) {
        if(c.before(res) || (c == res && side == 'right')) {
          // insert can split current line
          if(op.lines > 0 && res.line == c.line) {
            res = res.subtract(c.ch, 0)
                      .add(0, op.lines);
          } else {
            res = res.add(op.chars, op.lines);
          }
        }
        // advance cursor
        c = c.advance(op.chars, op.lines);
      } else if(op.isRemove) {
        var inRange = c.before(res) && res.before(c.advance(op.chars, op.lines));
        if(c.before(res) && !inRange) {
          // remove muiltiline range can join cursor row with position row, if they end up on the same row
          if (op.lines > 0 && (c.line + op.lines) == res.line) {
            res = new Position(res.ch + c.ch, c.line);
          } else {
            res = res.subtract(op.chars, op.lines);
          }
        } else if (inRange) {
          // we're collapsing range where current position is
          res = c;
        }
      } else {
        // KEEP, just advance our position
        c = c.advance(op.chars, op.lines);
      }

      // iterator break - if we passed calculated position, we can stop iterating over ops
      return res.before(c);
    });

    return res;
  }
}



