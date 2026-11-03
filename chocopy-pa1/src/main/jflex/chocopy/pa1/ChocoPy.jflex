package chocopy.pa1;

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.IdentityHashMap;
import java.util.Map;

import java_cup.runtime.*;

/*
 * ChocoPy lexer - PA1, group 5
 *
 * Most of this file is the usual keyword/operator list at the bottom. The
 * part that took us time is indentation, so a quick overview first.
 *
 * We use two states:
 *   YYINITIAL  start of a line, nothing read yet. Blank and comment-only
 *              lines are dropped here. For a real line we measure the
 *              leading whitespace and compare it with the indent stack.
 *   CODE       inside a line. Normal tokens. A line break gives NEWLINE
 *              and puts us back in YYINITIAL.
 *
 * The annoying case: one line can close several blocks, so it needs several
 * DEDENTs, but a JFlex action can only return one token. What we do is emit
 * one DEDENT and then yypushback() the whitespace. The next call reads the
 * same whitespace again, compares it with the (now smaller) stack and emits
 * the next DEDENT, until they match. That way we didn't need a token queue.
 *
 * Strings are matched with one regex and decoded in stringSymbol(). A quote
 * that is never closed just becomes a single UNRECOGNIZED token and we keep
 * lexing after it (the reference lexer does the same).
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

/* CODE = we are inside a line (see the comment at the top) */
%state CODE

%init{
    /* the manual (3.1.5) says the stack starts with a single 0 that is
     * never popped */
    indentStack.push(0);
%init}

/* The following code section is copied verbatim to the
 * generated lexer class. */
%{
    /** Producer of token-related values for the parser. */
    final ComplexSymbolFactory symbolFactory = new ComplexSymbolFactory();

    /** A tab moves to the next multiple of 8 (manual 3.1.5). */
    private static final int TAB_STOP = 8;

    /* ---- indentation ------------------------------------------------- */

    /** Indent levels of the blocks that are open right now. Bottom is
     *  always 0, and every level is bigger than the one below it. */
    private final Deque<Integer> indentStack = new ArrayDeque<>();

    /** Set while we are emitting DEDENTs for one line. We need it to spot
     *  a dedent that skips past the line's level without ever hitting it
     *  (see processIndentation). */
    private boolean dedenting = false;

    /* ---- end of file ------------------------------------------------- */

    /** Position for the next token we make up at end of file.
     *
     *  If the last line has no line break we pretend it has one: we emit
     *  the missing NEWLINE and put the following tokens on the next line,
     *  column 1.
     *
     *  Every EOF token after that is one column further right. That looks
     *  odd, but the reference does it (three DEDENTs at EOF end up at
     *  columns 1, 2 and 3) and block end positions come from these
     *  DEDENTs, so we had to copy it. It's in our bug report. */
    private int eofLine = -1;
    private int eofColumn = -1;

    /* ---- token text for error messages ------------------------------- */

    /** The source text of each token we return. The parser uses it for
     *  "Parse error near token X: <text>". The starter used yytext() there,
     *  but that's only the last match: it's wrong after a yypushback(), for
     *  tokens we invent at EOF, and while CUP reads ahead during error
     *  recovery. */
    private final Map<Symbol, String> tokenText = new IdentityHashMap<>();

    /** Source text of TOKEN ("" if we never stored any). */
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

    /** Same, but with an explicit text and location. Used for tokens
     *  whose position isn't just "the current match". */
    private Symbol symbol(int type, Object value, String text,
                          ComplexSymbolFactory.Location left,
                          ComplexSymbolFactory.Location right) {
        Symbol token = symbolFactory.newSymbol(
            ChocoPyTokens.terminalNames[type], type, left, right, value);
        tokenText.put(token, text);
        return token;
    }

    /** DEDENT or EOF that we create at end of file (one column wide). */
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

    /* ---- indentation logic ------------------------------------------- */

    /** Width of the leading whitespace WS. Space = 1 column, tab = jump
     *  to the next multiple of 8. */
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

    /** Runs at the start of every real line. yytext() is exactly the
     *  leading whitespace here (can be empty). Returns INDENT, DEDENT or
     *  UNRECOGNIZED, or null when the level doesn't change.
     *
     *  One token per call. If more DEDENTs are needed we push the
     *  whitespace back and end up here again on the next call. */
    private Symbol processIndentation() {
        int width = indentationWidth(yytext());
        int current = indentStack.peek();

        if (width == current) {
            /* same level, nothing to emit */
            dedenting = false;
            yybegin(CODE);
            return null;
        }

        if (width < current) {
            /* close the innermost block. The DEDENT's location is the
             * whitespace of this line - that's what the reference reports,
             * e.g. [19,1,19,8] for 8 spaces. We found this in coverage.py.ast */
            indentStack.pop();
            dedenting = true;
            Symbol dedent = symbol(ChocoPyTokens.DEDENT, "", "",
                new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1),
                new ComplexSymbolFactory.Location(yyline + 1, yycolumn + yylength()));
            yypushback(yylength());     /* read this line again next call */
            return dedent;
        }

        /* width > current */
        if (dedenting) {
            /* We went past this line's level without hitting it, e.g.
             * levels 0,4,8 and then a line indented by 2 (Python would say
             * "unindent does not match any outer indentation level").
             * The lexer isn't allowed to report errors, so we return
             * UNRECOGNIZED and the parser reports it.
             *
             * After that we just treat the line as part of the level we
             * reached. Our first version opened a new level here like the
             * reference does, but then the parser's recovery ate the INDENT
             * and the matching DEDENT caused a second, fake error. */
            dedenting = false;
            yybegin(CODE);
            return symbol(ChocoPyTokens.UNRECOGNIZED);
        }

        /* deeper line -> new block */
        indentStack.push(width);
        yybegin(CODE);
        return symbol(ChocoPyTokens.INDENT);
    }

    /* ---- literals ---------------------------------------------------- */

    /** INTEGER token, or UNRECOGNIZED if it doesn't fit in 32 bits
     *  (2147483647 is the largest allowed literal, manual 3.4.2). */
    private Symbol integerSymbol(String text) {
        try {
            return symbol(ChocoPyTokens.INTEGER, Integer.parseInt(text));
        } catch (NumberFormatException overflow) {
            return symbol(ChocoPyTokens.UNRECOGNIZED);
        }
    }

    /** Turns a whole string literal (with quotes) into a token.
     *
     *  Only \" \n \t and \\ are legal escapes. Any other escape (like \o)
     *  or a character outside ASCII 32..126 (a raw tab, say) makes the whole
     *  literal UNRECOGNIZED. We checked: the reference does the same. */
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
        /* if the contents look like an identifier it's an IDSTRING, which
         * is also allowed as a type, e.g. self: "Foo" */
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

/* A whole string literal. This regex only decides where the string ends;
 * stringSymbol() checks if the escapes and characters are legal.
 *
 * Yes, line breaks are allowed inside on purpose. Our fuzzer showed that the
 * reference lexer also runs to the next quote, even lines later, and then
 * rejects the whole thing. A backslash right before a line break stops the
 * match, again like the reference. If there is no closing quote at all, the
 * single " falls through to the UNRECOGNIZED rule at the bottom. */
StringLiteral = \" ([^\"\\] | \\[^\r\n])* \"

%%


/* ======================================================================
 * Start of a line: blank lines and indentation
 * ====================================================================== */
<YYINITIAL> {

  /* only spaces/tabs and maybe a comment: not a real line, so no NEWLINE
   * and its indentation doesn't count (manual 3.1.4) */
  {WhiteSpace}* {Comment}? {LineBreak}   { /* ignore */ }

  /* same thing on the last line when the file has no final newline */
  {WhiteSpace}* {Comment}                { /* ignore */ }
  {WhiteSpace}+                          { /* ignore */ }

  /* A real line. We match the whitespace plus the first real character
   * because JFlex can't fire on an empty match (indentation 0), then give
   * the character back so CODE lexes it normally. */
  {WhiteSpace}* [^ \t\r\n#]              {
                                           yypushback(1);
                                           Symbol token = processIndentation();
                                           if (token != null) {
                                               return token;
                                           }
                                         }
}


/* ======================================================================
 * Inside a line
 * ====================================================================== */
<CODE> {

  /* end of the line */
  {LineBreak}                 { yybegin(YYINITIAL);
                                return symbol(ChocoPyTokens.NEWLINE); }

  /* spaces between tokens and comments at the end of a line */
  {WhiteSpace}+               { /* ignore */ }
  {Comment}                   { /* ignore */ }

  /* Keywords. They have to come before the Identifier rule: on a tie JFlex
   * takes the first rule. "classic" is still an identifier because the
   * longest match wins. */
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

  /* Python keywords that ChocoPy doesn't use but still reserves (manual
   * 3.3). The reference calls them RESERVED. No grammar rule accepts them,
   * so e.g. "lambda = 5" is a syntax error. */
  "as" | "assert" | "async" | "await" | "break" | "continue" | "del"
  | "except" | "finally" | "from" | "import" | "lambda" | "raise"
  | "try" | "with" | "yield"
                              { return symbol(ChocoPyTokens.RESERVED); }

  /* names and numbers */
  {Identifier}                { return symbol(ChocoPyTokens.IDENTIFIER, yytext()); }
  {IntegerLiteral}            { return integerSymbol(yytext()); }

  /* strings (see the StringLiteral macro) */
  {StringLiteral}             { return stringSymbol(yytext()); }

  /* operators - longest match makes "<=" win over "<" */
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

  /* delimiters */
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
                                    /* last line had no line break: give
                                     * the NEWLINE it would have had */
                                    yybegin(YYINITIAL);
                                    ComplexSymbolFactory.Location here =
                                        new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
                                    eofLine = yyline + 2;
                                    eofColumn = 1;
                                    return symbol(ChocoPyTokens.NEWLINE, "", "", here, here);
                                default:
                                    /* close the open blocks, one DEDENT
                                     * per call, then EOF */
                                    if (indentStack.peek() > 0) {
                                        indentStack.pop();
                                        return eofSymbol(ChocoPyTokens.DEDENT);
                                    }
                                    return eofSymbol(ChocoPyTokens.EOF);
                                }
                              }

/* Anything else ($, &, !, or a " that never gets closed) -> UNRECOGNIZED.
 * The parser turns it into a syntax error. */
<CODE> [^]                    { return symbol(ChocoPyTokens.UNRECOGNIZED); }
