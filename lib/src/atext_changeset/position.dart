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
}



