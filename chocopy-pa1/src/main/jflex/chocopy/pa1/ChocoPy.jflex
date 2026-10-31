package chocopy.pa1;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.IdentityHashMap;
import java.util.Map;

import java_cup.runtime.*;

/*
 * ChocoPy lexer (PA1, group 5).
 *
 * The interesting part of this file is not the keyword/operator table at
 * the bottom (that part is mechanical); it is the way we turn leading
 * whitespace into INDENT / DEDENT tokens. The overall picture:
 *
 *   YYINITIAL  We are at the very beginning of a physical line. Nothing
 *              on this line has been tokenised yet. Here we either throw
 *              the whole line away (blank / comment-only line) or we
 *              measure its indentation and compare it with the stack.
 *
 *   CODE       We are in the middle of a logical line. Ordinary tokens
 *              are produced here. A line break emits NEWLINE and sends
 *              us back to YYINITIAL.
 *
 * String literals are matched as a whole by one regular expression and
 * then decoded in Java (see stringSymbol). A quote that is never closed
 * does not match that regex, so it falls back to a single UNRECOGNIZED
 * '"' token, and lexing carries on after it. The reference lexer
 * behaves the same way.
 *
 * A JFlex action can return at most one token, but one line can close
 * several blocks at once (and so needs several DEDENTs). We handle this
 * with yypushback(): after emitting one DEDENT we push the leading
 * whitespace back into the input. The next call to the lexer sees the
 * same whitespace again, compares it against the (now smaller) stack, and
 * emits the next DEDENT. This repeats until the levels match. No extra
 * token queue is needed.
 */

%%

/*** Do not change the flags below unless you know what you are doing. ***/

%unicode
%line
%column

%class ChocoPyLexer
%public

%cupsym ChocoPyTokens
%cup
%cupdebug

%eofclose false

/*** Do not change the flags above unless you know what you are doing. ***/

/* CODE: inside a logical line, producing regular tokens. */
%state CODE

%init{
    /* "Before the first line of the input program is read, a single zero
     *  is pushed on the stack; this will never be popped off again."
     *  (ChocoPy reference manual, section 3.1.5) */
    indentStack.push(0);
%init}

/* The following code section is copied verbatim to the
 * generated lexer class. */
%{
    /** Producer of token-related values for the parser. */
    final ComplexSymbolFactory symbolFactory = new ComplexSymbolFactory();

    /** Width a tab advances to: the next multiple of 8 (manual, 3.1.5). */
    private static final int TAB_STOP = 8;

    /* ------------------------------------------------------------------
     * Indentation bookkeeping
     * ------------------------------------------------------------------ */

    /** Indentation levels of the currently open blocks. The bottom is
     *  always 0 and the values strictly increase towards the top. */
    private final Deque<Integer> indentStack = new ArrayDeque<>();

    /** True while we are in the middle of emitting a run of DEDENTs for
     *  one line. If the stack runs past the line's level without hitting
     *  it exactly, the dedent was inconsistent (see processIndentation). */
    private boolean dedenting = false;

    /* ------------------------------------------------------------------
     * End-of-file bookkeeping
     * ------------------------------------------------------------------ */

    /** Where the next token made up at end of file will be placed.
     *
     *  If the last line has no line break, we act as if one were there: we
     *  emit the missing NEWLINE and put everything after it on the next
     *  line, column 1.
     *
     *  Each later EOF token moves one column to the right. The reference
     *  does this too: three DEDENTs at EOF sit at columns 1, 2 and 3. As a
     *  result an outer block ends one column after the block nested in
     *  it. We have to copy this because block locations are taken from
     *  these DEDENTs. */
    private int eofLine = -1;
    private int eofColumn = -1;

    /* ------------------------------------------------------------------
     * Token text for error messages
     * ------------------------------------------------------------------ */

    /** Source text of every token we hand out. The parser asks for it when
     *  it reports "Parse error near token X: <text>". We cannot use
     *  yytext() for that: after a yypushback(), or for a token we invent
     *  at end of file, yytext() no longer holds that token's text. And
     *  while CUP recovers from an error, it reads several tokens ahead. */
    private final Map<Symbol, String> tokenText = new IdentityHashMap<>();

    /** Return the source text of TOKEN, or "" if we never recorded any. */
    public String getTokenText(Symbol token) {
        String text = tokenText.get(token);
        return text == null ? "" : text;
    }

    /* ------------------------------------------------------------------
     * Token constructors
     * ------------------------------------------------------------------ */

    /** Return a terminal symbol of syntactic category TYPE and no
     *  semantic value at the current source location. */
    private Symbol symbol(int type) {
        return symbol(type, yytext());
    }

    /** Return a terminal symbol of syntactic category TYPE and semantic
     *  value VALUE at the current source location. */
    private Symbol symbol(int type, Object value) {
        return symbol(type, value, yytext(),
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1),
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + yylength()));
    }

    /** The general form: a token of category TYPE with semantic value
     *  VALUE and source text TEXT, spanning LEFT..RIGHT. */
    private Symbol symbol(int type, Object value, String text,
                          ComplexSymbolFactory.Location left,
                          ComplexSymbolFactory.Location right) {
        Symbol token = symbolFactory.newSymbol(
            ChocoPyTokens.terminalNames[type], type, left, right, value);
        tokenText.put(token, text);
        return token;
    }

    /** A one-column token invented at end of file (DEDENT or EOF). */
    private Symbol eofSymbol(int type) {
        if (eofLine < 0) {
            eofLine = yyline + 1;
            eofColumn = yycolumn + 1;
        }
        ComplexSymbolFactory.Location here =
            new ComplexSymbolFactory.Location(eofLine, eofColumn);
        eofColumn += 1;
        return symbol(type, "", "", here, here);
    }

    /* ------------------------------------------------------------------
     * Indentation
     * ------------------------------------------------------------------ */

    /** Indentation width of the whitespace WS: a space counts as one
     *  column, and a tab jumps to the next multiple of 8. */
    private static int indentationWidth(String ws) {
        int width = 0;
        for (int i = 0; i < ws.length(); i++) {
            if (ws.charAt(i) == '\t') {
                width = (width / TAB_STOP + 1) * TAB_STOP;
            } else {
                width += 1;
            }
        }
        return width;
    }

    /** Called at the start of every logical line, while yytext() holds
     *  exactly the line's leading whitespace (possibly empty). Returns
     *  the INDENT / DEDENT / UNRECOGNIZED token to emit, or null if the
     *  line stays at the current level.
     *
     *  Only one token is produced per call. When more DEDENTs are needed,
     *  the whitespace is pushed back so that we come here again on the
     *  next call, until the stack and the line agree. */
    private Symbol processIndentation() {
        int width = indentationWidth(yytext());
        int current = indentStack.peek();

        if (width == current) {
            /* Same block: nothing to emit, start lexing the line. */
            dedenting = false;
            yybegin(CODE);
            return null;
        }

        if (width < current) {
            /* Close the innermost block. The DEDENT covers the whitespace
             * of the line that closes it, which is the position the
             * reference reports (e.g. [19,1,19,8] for 8 spaces). */
            indentStack.pop();
            dedenting = true;
            Symbol dedent = symbol(ChocoPyTokens.DEDENT, "", "",
                new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1),
                new ComplexSymbolFactory.Location(yyline + 1, yycolumn + yylength()));
            yypushback(yylength());     /* look at this line again */
            return dedent;
        }

        /* width > current */
        if (dedenting) {
            /* We popped past this line's level without ever matching it,
             * e.g. levels 0,4,8 and a line indented by 2. Python calls
             * this "unindent does not match any outer indentation level".
             * The lexer must not report errors itself, so it emits an
             * UNRECOGNIZED token that no grammar rule accepts.
             *
             * The line is then treated as belonging to the enclosing level
             * we just reached. Opening a new level here (as the reference
             * does) would emit an INDENT that the parser's error recovery
             * throws away, while the matching DEDENT later shows up as a
             * second, misleading error. */
            dedenting = false;
            yybegin(CODE);
            return symbol(ChocoPyTokens.UNRECOGNIZED);
        }

        /* A deeper line opens a new block. */
        indentStack.push(width);
        yybegin(CODE);
        return symbol(ChocoPyTokens.INDENT);
    }

    /* ------------------------------------------------------------------
     * Literals
     * ------------------------------------------------------------------ */

    /** Integer literal token for TEXT, or UNRECOGNIZED if it does not fit
     *  in 32 bits (the manual makes 2147483647 the largest literal). */
    private Symbol integerSymbol(String text) {
        try {
            return symbol(ChocoPyTokens.INTEGER, Integer.parseInt(text));
        } catch (NumberFormatException overflow) {
            return symbol(ChocoPyTokens.UNRECOGNIZED);
        }
    }

    /** Token for the complete string literal TEXT (quotes included).
     *
     *  The value is the text between the quotes with the four legal escapes
     *  (\" \n \t \\) applied. The literal is UNRECOGNIZED if it holds any
     *  other escape (e.g. \o) or a character outside printable ASCII
     *  32..126 (e.g. a tab). The reference treats both cases that way too. */
    private Symbol stringSymbol(String text) {
        StringBuilder value = new StringBuilder();
        boolean legal = true;
        for (int i = 1; i < text.length() - 1; i++) {
            char c = text.charAt(i);
            if (c == '\\') {
                char escaped = text.charAt(++i);
                switch (escaped) {
                case '"':  value.append('"');  break;
                case 'n':  value.append('\n'); break;
                case 't':  value.append('\t'); break;
                case '\\': value.append('\\'); break;
                default:   legal = false;      break;
                }
            } else if (c < 32 || c > 126) {
                legal = false;
            } else {
                value.append(c);
            }
        }
        if (!legal) {
            return symbol(ChocoPyTokens.UNRECOGNIZED);
        }
        /* A string whose contents look like an identifier can also be used
         * as a type annotation, e.g. self: "Foo". */
        String contents = value.toString();
        int type = contents.matches("[a-zA-Z_][a-zA-Z0-9_]*")
            ? ChocoPyTokens.IDSTRING : ChocoPyTokens.STRING;
        return symbol(type, contents);
    }
%}

/* Macros (regexes used in rules below) */

WhiteSpace = [ \t]
LineBreak  = \r\n|\r|\n
Comment    = "#" [^\r\n]*

IntegerLiteral = 0 | [1-9][0-9]*
Identifier     = [a-zA-Z_][a-zA-Z0-9_]*

/* A complete string literal: a quote, then any characters except a quote
 * or a backslash, or a backslash followed by any character other than a
 * line break, then the closing quote. This only fixes where the literal ends. Whether its
 * escapes and characters are legal is checked in stringSymbol().
 *
 * Line breaks are allowed in this regex on purpose. The reference
 * lexer also runs up to the next quote, even on a later line, and then
 * rejects the literal because a line break is not printable ASCII. Only
 * a quote with no partner anywhere later in the file falls back to the
 * single-character UNRECOGNIZED rule. (A backslash directly before a line
 * break also ends the match there, again like the reference.) */
StringLiteral = \" ([^\"\\] | \\[^\r\n])* \"

%%


/* ======================================================================
 * Start of a physical line: blank lines and indentation
 * ====================================================================== */
<YYINITIAL> {

  /* A line holding only whitespace and/or a comment is not a logical
   * line: no NEWLINE, and its indentation is ignored (manual, 3.1.4). */
  {WhiteSpace}* {Comment}? {LineBreak}   { /* ignore */ }

  /* The same, but on the last line of a file without a final newline. */
  {WhiteSpace}* {Comment}                { /* ignore */ }
  {WhiteSpace}+                          { /* ignore */ }

  /* A real logical line. We match its leading whitespace plus the first
   * real character so that the match is never empty, then give that
   * character back so the CODE state can lex it as usual. */
  {WhiteSpace}* [^ \t\r\n#]              {
                                           yypushback(1);
                                           Symbol token = processIndentation();
                                           if (token != null) {
                                               return token;
                                           }
                                         }
}


/* ======================================================================
 * Inside a logical line
 * ====================================================================== */
<CODE> {

  /* End of the logical line. */
  {LineBreak}                 { yybegin(YYINITIAL);
                                return symbol(ChocoPyTokens.NEWLINE); }

  /* Whitespace between tokens and trailing comments are skipped. */
  {WhiteSpace}+               { /* ignore */ }
  {Comment}                   { /* ignore */ }

  /* Keywords that ChocoPy actually uses. These come before the
   * Identifier rule; JFlex breaks equal-length ties by rule order, and
   * longest match still makes "classic" an identifier. */
  "False"                     { return symbol(ChocoPyTokens.FALSE); }
  "None"                      { return symbol(ChocoPyTokens.NONE); }
  "True"                      { return symbol(ChocoPyTokens.TRUE); }
  "and"                       { return symbol(ChocoPyTokens.AND); }
  "class"                     { return symbol(ChocoPyTokens.CLASS); }
  "def"                       { return symbol(ChocoPyTokens.DEF); }
  "elif"                      { return symbol(ChocoPyTokens.ELIF); }
  "else"                      { return symbol(ChocoPyTokens.ELSE); }
  "for"                       { return symbol(ChocoPyTokens.FOR); }
  "global"                    { return symbol(ChocoPyTokens.GLOBAL); }
  "if"                        { return symbol(ChocoPyTokens.IF); }
  "in"                        { return symbol(ChocoPyTokens.IN); }
  "is"                        { return symbol(ChocoPyTokens.IS); }
  "nonlocal"                  { return symbol(ChocoPyTokens.NONLOCAL); }
  "not"                       { return symbol(ChocoPyTokens.NOT); }
  "or"                        { return symbol(ChocoPyTokens.OR); }
  "pass"                      { return symbol(ChocoPyTokens.PASS); }
  "return"                    { return symbol(ChocoPyTokens.RETURN); }
  "while"                     { return symbol(ChocoPyTokens.WHILE); }

  /* Python keywords with no meaning in ChocoPy. They are reserved so that
   * every legal ChocoPy program is also legal Python (manual, 3.3). No
   * grammar rule uses RESERVED, so using one is a syntax error. */
  "as" | "assert" | "async" | "await" | "break" | "continue" | "del"
  | "except" | "finally" | "from" | "import" | "lambda" | "raise"
  | "try" | "with" | "yield"
                              { return symbol(ChocoPyTokens.RESERVED); }

  /* Identifiers and integer literals. */
  {Identifier}                { return symbol(ChocoPyTokens.IDENTIFIER, yytext()); }
  {IntegerLiteral}            { return integerSymbol(yytext()); }

  /* String literals. */
  {StringLiteral}             { return stringSymbol(yytext()); }

  /* Operators. Longest match makes "//" beat "/" and "<=" beat "<". */
  "+"                         { return symbol(ChocoPyTokens.PLUS); }
  "-"                         { return symbol(ChocoPyTokens.MINUS); }
  "*"                         { return symbol(ChocoPyTokens.TIMES); }
  "//"                        { return symbol(ChocoPyTokens.IDIV); }
  "%"                         { return symbol(ChocoPyTokens.MOD); }
  "<"                         { return symbol(ChocoPyTokens.LT); }
  ">"                         { return symbol(ChocoPyTokens.GT); }
  "<="                        { return symbol(ChocoPyTokens.LEQ); }
  ">="                        { return symbol(ChocoPyTokens.GEQ); }
  "=="                        { return symbol(ChocoPyTokens.EQEQ); }
  "!="                        { return symbol(ChocoPyTokens.NEQ); }
  "="                         { return symbol(ChocoPyTokens.EQ); }

  /* Delimiters. */
  "("                         { return symbol(ChocoPyTokens.LPAREN); }
  ")"                         { return symbol(ChocoPyTokens.RPAREN); }
  "["                         { return symbol(ChocoPyTokens.LINDEX); }
  "]"                         { return symbol(ChocoPyTokens.RINDEX); }
  ","                         { return symbol(ChocoPyTokens.COMMA); }
  ":"                         { return symbol(ChocoPyTokens.COLON); }
  "."                         { return symbol(ChocoPyTokens.DOT); }
  "->"                        { return symbol(ChocoPyTokens.ARROW); }
}


/* ======================================================================
 * End of file
 * ====================================================================== */
<<EOF>>                       {
                                switch (yystate()) {
                                case CODE:
                                    /* The last line had no line break. Emit
                                     * the NEWLINE it would have produced;
                                     * later tokens go on the next line. */
                                    yybegin(YYINITIAL);
                                    ComplexSymbolFactory.Location here =
                                        new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
                                    eofLine = yyline + 2;
                                    eofColumn = 1;
                                    return symbol(ChocoPyTokens.NEWLINE, "", "", here, here);
                                default:
                                    /* Close every block that is still open,
                                     * one DEDENT per call, then EOF. */
                                    if (indentStack.peek() > 0) {
                                        indentStack.pop();
                                        return eofSymbol(ChocoPyTokens.DEDENT);
                                    }
                                    return eofSymbol(ChocoPyTokens.EOF);
                                }
                              }

/* Error fallback: a character that starts no token (e.g. $, &, !, or a
 * double quote that never gets closed). */
<CODE> [^]                    { return symbol(ChocoPyTokens.UNRECOGNIZED); }
