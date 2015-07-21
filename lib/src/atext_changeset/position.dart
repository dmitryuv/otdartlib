part of otdartlib.atext_changeset;

class Position implements Clonable {
  int ch = 0;
  int line = 0;
  
  Position([this.ch = 0, this.line = 0]);
  
  /**
   * Returns true if current position is before other position
   */
  bool before(Position other) => (line < other.line) || (line == other.line && ch < other.ch);

  int get hashCode => hash2(ch, line);
  
  bool operator==(other) => other is Position && line == other.line && ch == other.ch;
  
  /**
   * Clone this position object into new one
   */
  @override
  Position clone() => new Position(ch, line);
 
  /**
   * Adding lines does not alter char position in new line
   */
  void add(int chars, int lines) {
    if(lines != 0) {
      line += lines;
    } else {
      ch += chars;
    }
  }

  /**
   * Unlike adding, advance uses changeset logic to advance between lines
   * i.e. moving to next line resets char position
   */
  void advance(int chars, int lines) {
    add(chars, lines);
    if(lines != 0) {
      ch = 0;
    }
  }
  
  /**
   * Subtracts component chars or lines from position. Char position on this line should not be affected
   * if we're removing other linesэ
   */
  void subtract(int chars, int lines) {
    if(lines != 0) {
      line -= lines;
    } else {
      ch -= chars;
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

    var res = this.clone();
    // iteration cursor
    var c = new Position();

    op.any((op) {
      if(op.isInsert) {
        if(c.before(res) || (c == res && side == 'right')) {
          // insert can split current line
          if(op.lines > 0 && res.line == c.line) {
            res..subtract(c.ch, 0)
              ..add(0, op.lines);
          } else {
            res.add(op.chars, op.lines);
          }
        }
        // advance cursor
        c.advance(op.chars, op.lines);
      } else if(op.isRemove) {
        var inRange = c.before(res) && res.before(c.clone()..advance(op.chars, op.lines));
        if(c.before(res) && !inRange) {
          // remove muiltiline range can join cursor row with position row, if they end up on the same row
          if (op.lines > 0 && (c.line + op.lines) == res.line) {
            res.add(c.ch, 0);
            res.line = c.line;
          } else {
            res.subtract(op.chars, op.lines);
          }
        } else if (inRange) {
          // we're collapsing range where current position is
          res = c.clone();
        }
      } else {
        // KEEP, just advance our position
        c.advance(op.chars, op.lines);
      }

      // iterator break - if we passed calculated position, we can stop iterating over ops
      return res.before(c);
    });

    return res;
  }
}



