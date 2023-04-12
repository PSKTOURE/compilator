grammar Calculette;

@header {
    import java.util.LinkedList;
}

@members {   
    /** tables des symboles pour les  */
    private TablesSymboles tablesSymboles = new TablesSymboles();
    
    /** générateur de nom d'étiquettes pour les boucles */
    private int _cur_label = 1;
    private String getNewLabel() { return "Label" +(_cur_label++); }

    /** pile pour les label de if_else_end dans le cas de elif */
    private LinkedList<String> elif_out_labels = new LinkedList<>();

    private String getOp(String op) {
        if(op.equals("=="))
            return "EQUAL";
        else if(op.equals("!=") || op.equals("<>"))
            return "NEQ";
        else if(op.equals("<="))
            return "INFEQ";
        else if(op.equals("<"))
            return "INF";
        else if(op.equals(">="))
            return "SUPEQ";
        else if(op.equals(">"))
            return "SUP";
        System.err.println("Not supposed to happen (compiler getOp function)");
        System.exit(2);
        return "";
    }
}

start : calcul  EOF ;

calcul returns [ String code ] 

@init{ $code = new String(); }   // On initialise code, pour l'utiliser comme accumulateur 
@after{ System.out.println($code); } // On affiche l’ensemble du code produit
    :   (decl { $code += $decl.code; })*        
        { $code += "  CALL Main\n"; } // On utilise un CALL main pour bénéfichier des variables locales directement via des blocs
        NEWLINE*
        
        (fonction { $code += $fonction.code; })* 
        NEWLINE*

        { $code += "LABEL Main\n"; }
        (instruction { $code += $instruction.code; })*

        {
            $code += "  FREE " + (tablesSymboles.getVariableGlobaleSize() + 2) + "\n";
            $code += "  HALT\n";
        } 
    ;

// -------------------- Instructions

instruction returns [ String code ] 
    : RETURN e=expression finInstruction
        {
            $code = $e.code;
            VariableInfo vi = tablesSymboles.getReturn();
            if(vi.type.equals("int")) {
                if($e.type.equals("double")) {
                    $code += "  FTOI\n";
                    System.err.println("\nWarning: Implicit conversion from integer to double.");
                } else if(!$e.type.equals("int")) { 
                    System.err.println("\nError: Wrong type cast in return value;");
                    System.exit(1); 
                }
                $code += "  STOREL " + tablesSymboles.getReturn().address + "\n"; 
            } else if(vi.type.equals("double")) {
                if($e.type.equals("int")) {
                    $code += "  ITOF\n";
                    System.err.println("\nWarning: Implicit conversion from double to integer.");
                } else if(!$e.type.equals("double")) { 
                    System.err.println("\nError: Wrong type cast in return value;");
                    System.exit(1); 
                }
                $code += "  STOREL " + (tablesSymboles.getReturn().address + 1) + "\n"; 
                $code += "  STOREL " + tablesSymboles.getReturn().address + "\n"; 
            } else if (vi.type.equals("bool")) {
                if($e.type.equals("int")) {
                    $code += "  PUSHI 0\n";
                    $code += "  NEQ\n";
                    System.err.println("\nWarning: Implicit conversion from integer to bool.");
                } else if($e.type.equals("double")) {
                    $code += "  PUSHF 0.0\n";
                    $code += "  FNEQ\n";
                    System.err.println("\nWarning: Implicit conversion from double to bool.");
                } else if(!$e.type.equals("bool")) { 
                    System.err.println("\nError: Wrong type cast in return value;");
                    System.exit(1); 
                }
                $code += "  STOREL " + tablesSymboles.getReturn().address + "\n"; 
            } else {
                System.err.println("Not implemented return type other than int or double, yet.");
                System.exit(1);
            }
            $code += "  RETURN\n";
        }
    | expression finInstruction 
        { 
            $code = $expression.code;
            $code += "  POP\n";
            if($expression.type.equals("double"))
                $code += "  POP\n";
        }
    | assignation finInstruction
        {
            $code = $assignation.code;
        }
    | decl finInstruction
        {
            $code = $decl.code;
        }
    | loop_while
        {
            $code = $loop_while.code;
        }
    | loop_for
        {
            $code = $loop_for.code;
        }
    | condition finInstruction
        {
            $code = $condition.code;
            $code += "  \nPOP";
        }
    | if_else
        {
            $code = $if_else.code;
        }
    | bloc
        {
            $code = $bloc.code;
        }
    | print finInstruction
        {
            $code = $print.code;
        }
    | BREAK finInstruction
        {
            String end = tablesSymboles.getCurrentLoopEnd();
            if(end == null) {
                System.err.println("Error at line " + $BREAK.getLine() + ": break placed here when not in a loop.");
                System.exit(1);
            }

            $code = "  JUMP " + end;
        }
    | CONTINUE finInstruction
        {
            String start = tablesSymboles.getCurrentLoopStart();
            if(start == null) {
                System.err.println("Error at line " + $CONTINUE.getLine() + ": continue placed here when not in a loop.");
                System.exit(1);
            }

            $code = "  JUMP " + start;
        }
    | finInstruction
        {
            $code = "";
        }   
    ;

// -------------------- Expressions

expression returns [ String code, String type ]
    : '-' a=expression
        {
            boolean isBool = false;
            if($a.type.equals("bool")) {
                System.err.println("\nWarning: Implicit cast from bool to int");
                isBool = true;
            }

            if($a.type.equals("int") || isBool)
                $code = "  PUSHI -1\n" + $a.code + "  MUL\n";
            else if($a.type.equals("double"))
                $code = "  PUSHF - 1.0\n" + $a.code + "  FMUL\n";

            $type = $a.type;
        } 
    | '(' a=expression ')' { $code = $expression.code; $type = $a.type; }
    | a=expression op=('*'|'/') b=expression
        {
            if( ! $a.type.equals($b.type) ) {
                System.err.println("\nError: Can't do arithmetic operations between expression of type " + $a.type + " and " + $b.type);
                System.err.println("At line: " + $a.start.getLine());
                System.exit(1);
            }
            
            if($a.type.equals("int"))
                $code = $a.code + $b.code + ( $op.text.equals("*") ? "  MUL\n" : "  DIV\n" );
            else if($a.type.equals("double"))
                $code = $a.code + $b.code + ( $op.text.equals("*") ? "  FMUL\n" : "  FDIV\n" );
            else {
                System.err.println("\nError: can't do arithmetic operactions with type " + $a.type);
                System.exit(1);
            }
            $type = $a.type;
        }
    | a=expression op=('+'|'-') b=expression
        {
            if( ! $a.type.equals($b.type) ) {
                System.err.println("\nError: Can't do arithmetic operations between a float and an integer.");
                System.exit(1);
            }
            if($a.type.equals("int"))
                $code = $a.code + $b.code + ( $op.text.equals("+") ? "  ADD\n" : "  SUB\n" );
            else if($a.type.equals("double"))
                $code = $a.code + $b.code + ( $op.text.equals("+") ? "  FADD\n" : "  FSUB\n" );
            else {
                System.err.println("\nError: can't do arithmetic operactions with type " + $a.type);
                System.exit(1);
            }

            $type = $a.type;
        }
    | FLOTANT
        {
            $code = "  PUSHF " + Double.parseDouble($FLOTANT.text) + "\n";
            $type = "double";
        }
    | ENTIER
        {
            $code = "  PUSHI " + $ENTIER.text + "\n";
            $type = "int";
        }
    | id=IDENTIFIANT
        {
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            Integer deepness = pair.getValue();
            
            String push = "  PUSHG ";

            if(v.scope != VariableInfo.Scope.GLOBAL) {
                push = "  PUSHL ";
            }
            if(deepness < 1) {
                $code = push + v.address + "\n";
                if(v.type.equals("double")) {
                    $code += push + (v.address + 1) + "\n";
                }
            } else {
                String getting = tablesSymboles.getVarDeep(v, $id.text);
                $code = getting;
                $code += "  PUSHR " + v.address + "\n";
                if(v.type.equals("double")) {
                    $code += getting;
                    $code += "  PUSHR " + (v.address + 1) + "\n";
                }
            }
            $type = v.type;
        }
    | id=IDENTIFIANT '(' ')' // appel de fonction
        {
            Pair<String, String> pair = tablesSymboles.getFunction($id.text);
            String type = pair.getValue();
            String label = pair.getKey();
            $code = "";
            if (type == null)
                System.exit(1);
            else if (type.equals("int") || type.equals("bool")) {
                $code += "  PUSHI 0\n";
            } else if (type.equals("double")) {
                $code += "  PUSHF 0.0\n";
            }
            $type = type;
            $code += "  CALL " + label + "\n";
        }
    | id=IDENTIFIANT '(' argz=args ')' // appel de fonction
        {
            //String type = tablesSymboles.getFunction($id.text);
            Pair<String, String> pair = tablesSymboles.getFunction($id.text);
            String type = pair.getValue();
            String label = pair.getKey();
            $code = "";
            if (type == null)
                System.exit(1);
            else if (type.equals("int") || type.equals("bool")) {
                $code += "  PUSHI 0\n";
            } else if (type.equals("double")) {
                $code += "  PUSHF 0.0\n";
            }

            $code += $argz.code;
            $type = type;
            $code += "  CALL " + label + "\n";
            
            for (int i = 0; i < $argz.size; i++) {
                $code += "  POP\n";
            }
        }
    | '(' t=(TYPE|BOOL) ')' e=expression
        {
            $code = $e.code;
            if($e.type.equals($t.text))
                System.err.println("\nWarning: Useless cast. Expression already of cast type.");
            else if($e.type.equals("int")) {
                if($t.text.equals("double"))
                    $code += "  ITOF\n";
                else if($t.text.equals("bool")) {
                    $code += "  PUSHI 0\n";
                    $code += "  NEQ\n";
                } else {
                    System.err.println("\nError: Cast " + $t.type + " from int not implemented.");
                    System.exit(1);
                }
            } else if($e.type.equals("double")) {
                if($t.text.equals("int"))
                    $code += "  FTOI\n";
                else if($t.text.equals("bool")) {
                    $code += "  PUSHF 0.0\n";
                    $code += "  FNEQ\n";
                } else {
                    System.err.println("\nError: Cast " + $t.type + " from double not implemented.");
                    System.exit(1);
                }
            } else if($e.type.equals("bool")) {
                if($t.text.equals("double"))
                    $code += "  ITOF\n";
                else if(!$t.text.equals("int")) {
                    System.err.println("\nError: Cast " + $t.type + " from int not implemented.");
                    System.exit(1);
                }
            }
            else {
                System.err.println("\nError: Unvalid cast type. From " + $e.type +" to " + $t.text);
                System.exit(1);
            }
            $type = $t.text;
    
        }
    | id = IDENTIFIANT '['exp = expression']'
        {
            if(!$exp.type.equals("int")){
                System.err.println("Acces Error, wrong index type");
                System.exit(1);
            }
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            String push = "  PUSHL ";
            if(v.scope == VariableInfo.Scope.GLOBAL) {
                push = "  PUSHI ";
            }
            String temp = v.type;
            temp = temp.substring(0, temp.length() - 2);
            $type = temp;
            $code = push + v.address + "\n";
            $code += $exp.code;
            if(temp.equals("int")){
                $code += "  ADD\n";
                $code += "  PUSHR 0\n";
            }
            else if(temp.equals("double")){
                $code += "  PUSHI 2\n";
                $code += "  MUL\n  ADD\n";
                $code += "  PUSHR 0\n";
                $code += push + v.address + "\n";
                $code += $exp.code;
                $code += "  PUSHI 2\n";
                $code += "  MUL\n  ADD\n";
                $code += "  PUSHR 1\n";
            }
        }
    ;

// -------------------- Declarations

decl returns [ String code ]
    : t=(TYPE | BOOL) id=IDENTIFIANT finInstruction
        {   
            if($t.text.equals("int") || $t.text.equals("bool")) {
                tablesSymboles.addVarDecl($id.text, $t.text, true);
                $code = "  PUSHI 0\n";
            } else if($t.text.equals("double")){
                tablesSymboles.addVarDecl($id.text,"double", true);
                $code = "  PUSHF 0.0\n";
            } else {
                System.err.println("\nError: Unsupported type " + $t.text);
                System.exit(1);
            }
        }
    | t=TYPE id=IDENTIFIANT '=' exp=expression finInstruction
        {
            if($t.text.equals("int")) {
                tablesSymboles.addVarDecl($id.text, "int", true);
                Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
                VariableInfo v = pair.getKey();
                //VariableInfo v = tablesSymboles.getVar($id.text);
                $code = "  PUSHI 0\n";
                $code += $exp.code;
                String store = "  STOREL ";

                if($exp.type.equals("bool")) {
                    System.err.println("\nWarning: Implicit conversion from bool to int in declaration.");
                } else if(! $exp.type.equals("int")){
                    System.err.println("\nError: Unannonced conversion from " + $exp.type + " to int in declaration.");
                    System.exit(1);
                }
            
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + v.address + "\n";
            } else if ($t.text.equals("double")) {
                tablesSymboles.addVarDecl($id.text, "double", true);
                Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
                VariableInfo v = pair.getKey();
                //VariableInfo v = tablesSymboles.getVar($id.text);
                $code = "  PUSHF 0.0\n";
                $code += $exp.code;
                if($exp.type.equals("int")) {
                    $code += "  ITOF\n";
                    System.err.println("\nWarning: Implicit conversion from int to float in declaration.");
                } else if(! $exp.type.equals("double")) {
                    System.err.println("\nError: Unannonced conversion from " + $exp.type + " to float in declaration.");
                    System.exit(1);
                }
                String store = "  STOREL ";
            
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + (v.address + 1) + "\n";
                $code += store + v.address + "\n";
            } else if($t.text.equals("bool")) {
                tablesSymboles.addVarDecl($id.text, "bool", true);
                //VariableInfo v = tablesSymboles.getVar($id.text);
                Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
                VariableInfo v = pair.getKey();
                $code = "  PUSHI 0\n";
                $code += $exp.code;
                String store = "  STOREL ";

                if($exp.type.equals("int")) {
                    System.err.println("\nWarning: Implicit conversion from int to bool in declaration.");
                    $code += "  PUSHI 0\n";
                    $code += "  NEQ\n";
                } else if($exp.type.equals("double")) {
                    System.err.println("\nWarning: Implicit conversion from double to bool in declaration.");
                    $code += "  PUSHF 0.0\n";
                    $code += "  FNEQ\n";
                } else if(! $exp.type.equals("bool"))  {
                    System.err.println("\nError: Unannonced conversion from " + $exp.type + " to int in declaration.");
                    System.exit(1);
                }
            
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + v.address + "\n";
            }
        }
    | BOOL id=IDENTIFIANT '=' cdt=condition finInstruction
        { 
            tablesSymboles.addVarDecl($id.text, "bool", true);
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            $code = "  PUSHI 0\n";
            $code += $cdt.code;
            String store = "  STOREL ";
            if(v.scope == VariableInfo.Scope.GLOBAL)
                store = "  STOREG ";
            $code += store + v.address + "\n";
        }
    | c=CONST t=TYPE id=IDENTIFIANT '=' exp=expression finInstruction
        {
            if($t.text.equals("int")) {
                tablesSymboles.addVarDecl($id.text, "int", false);
                //VariableInfo v = tablesSymboles.getVar($id.text);
                Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
                VariableInfo v = pair.getKey();
                $code = "  PUSHI 0\n";
                $code += $exp.code;
                String store = "  STOREL ";

                if($exp.type.equals("bool")) {
                    System.err.println("\nWarning: Implicit conversion from bool to int in declaration.");
                } else if(! $exp.type.equals("int")) {
                    System.err.println("\nError: Unannonced conversion from " + $exp.type + " to int in declaration.");
                    System.exit(1);
                }
            
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + v.address + "\n";
            } else if ($t.text.equals("double")){
                tablesSymboles.addVarDecl($id.text, "double", false);
                //VariableInfo v = tablesSymboles.getVar($id.text);
                Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
                VariableInfo v = pair.getKey();
                $code = "  PUSHF 0.0\n";
                $code += $exp.code;
                if($exp.type.equals("int")) {
                    $code += "  ITOF\n";
                    System.err.println("\nWarning: Implicit conversion from int to float in declaration.");
                } else if(! $exp.type.equals("double")) {
                    System.err.println("\nError: Unannonced conversion from " + $exp.type + " to float in declaration.");
                    System.exit(1);
                }
                String store = "  STOREL ";
            
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + (v.address + 1) + "\n";
                $code += store + v.address + "\n";
            } else if($t.text.equals("bool")) {
                tablesSymboles.addVarDecl($id.text, "bool", false);
                //VariableInfo v = tablesSymboles.getVar($id.text);
                Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
                VariableInfo v = pair.getKey();
                $code = "  PUSHI 0\n";
                $code += $exp.code;
                String store = "  STOREL ";

                if($exp.type.equals("int")) {
                    System.err.println("\nWarning: Implicit conversion from int to bool in declaration.");
                    $code += "  PUSHI 0\n";
                    $code += "  NEQ\n";
                } else if($exp.type.equals("double")) {
                    System.err.println("\nWarning: Implicit conversion from double to bool in declaration.");
                    $code += "  PUSHF 0.0\n";
                    $code += "  FNEQ\n";
                } else if(! $exp.type.equals("bool")) {
                    System.err.println("\nError: Unannonced conversion from " + $exp.type + " to int in declaration.");
                    System.exit(1);
                }
            
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + v.address + "\n";
            }
        }
    | CONST BOOL id=IDENTIFIANT '=' cdt=condition finInstruction
        { 
            tablesSymboles.addVarDecl($id.text, "bool", false);
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();

            $code = "  PUSHI 0\n";
            $code += $cdt.code;
            String store = "  STOREL ";
            if(v.scope == VariableInfo.Scope.GLOBAL)
                store = "  STOREG ";
            $code += store + v.address + "\n";
        }
    | t=TYPE  id=IDENTIFIANT '['e=ENTIER']' finInstruction
        {   
            int arraySize = $e.int;
            String arrayType = $t.text + "[]";
            if($t.text.equals("double"))
                arraySize *= 2;
            tablesSymboles.addVarDecl($id.text, arrayType, true, arraySize);
            $code = "  ALLOC " + arraySize + "\n";
        }
    | t=TYPE '['e=ENTIER']' id=IDENTIFIANT  finInstruction
        {   
            int arraySize = $e.int;
            String arrayType = $t.text + "[]";
            if($t.text.equals("double"))
                arraySize *= 2;
            tablesSymboles.addVarDecl($id.text, arrayType, true, arraySize);
            $code = "  ALLOC " + arraySize + "\n";
        } 
    ;

// -------------------- Assignations

assignation returns [ String code ]
    : id=IDENTIFIANT '=' exp=expression 
        {
            //VariableInfo v = tablesSymboles.getVar($id.text);
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            Integer deepness = pair.getValue();
            String store = "  STOREL ";
            
            if(v.scope == VariableInfo.Scope.GLOBAL) {
                store = "  STOREG ";
            }
            if(v.mutable) {
                if(!v.type.equals($exp.type)) {
                    System.err.println("Can't assign value of a different type to variable");
                    System.exit(1);
                }
                if(deepness < 1) {
                    if(v.type.equals("int") || v.type.equals("bool")) {
                        $code = $exp.code + store + v.address + "\n";
                    } else if(v.type.equals("double")) {
                        $code = $exp.code + store + (v.address + 1) + "\n";
                        $code += store + v.address + "\n";
                    }
                } else {
                    String getting = tablesSymboles.getVarDeep(v, $id.text);

                    if(v.type.equals("int") || v.type.equals("bool")) {
                        $code = getting;
                        $code += $exp.code;
                        $code += "  STORER " + v.address + "\n";
                    } else {
                        $code = $exp.code;
                        $code += getting;
                        $code += "  DUP\n";
                        $code += "  PUSHSP\n";
                        $code += "  PUSHR -3\n";
                        $code += "  STORER " + (v.address + 1) +"\n";
                        $code += "  PUSHSP\n";
                        $code += "  PUSHR -3\n";
                        $code += "  STORER " + (v.address) +"\n";
                        $code += "  POP\n  POP\n";
                    }
                }

            } else {
                System.err.println("\nErreur: vous ne pouvez pas modifier une constante");
                System.exit(1);
            }
        }
    | id = IDENTIFIANT '['e=expression']' '=' exp=expression
        {
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();

            String arrType = v.type.substring(0, v.type.length() - 2);
            if(!arrType.equals($exp.type)) {
                System.err.println("Can't assign value of a different type to variable");
                System.exit(1);
            }
            String push = "  PUSHL ";
            if(v.scope == VariableInfo.Scope.GLOBAL) {
                push = "  PUSHI ";
            }

            if(arrType.equals("int") || arrType.equals("bool")){
                $code = push + v.address + "\n";
                $code += $e.code;
                $code += "  ADD\n";
                $code += $exp.code;
                $code += "  STORER 0\n";
            }
            else if(arrType.equals("double")){
                $code = $exp.code;
                $code += $e.code;
                $code += "  PUSHI 2\n  MUL\n";
                $code += push + v.address + "\n";
                $code += "  ADD\n";
                $code += "  DUP\n";
                $code += "  PUSHSP\n";
                $code += "  PUSHR -4\n";
                $code += "  STORER 0\n";
                $code += "  PUSHI 1\n  ADD\n";
                $code += "  PUSHSP\n  PUSHR -2\n";
                $code += "  STORER 0\n  POP\n  POP\n";
            }

        }
    | id = IDENTIFIANT '['e=expression']' (op=('+'|'-'|'*'|'/')'=') exp=expression 
         {
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            String arrType = v.type.substring(0, v.type.length() - 2);
            if(!arrType.equals($exp.type)) {
                System.err.println("Can't assign value of a different type to variable");
                System.exit(1);
            }
            String push = "  PUSHL ";
            if(v.scope == VariableInfo.Scope.GLOBAL) {
                push = "  PUSHI ";
            }
            $code = push + v.address + "\n";  
            $code += $e.code;
            if(arrType.equals("int") || arrType.equals("bool")){
                $code += "  ADD\n";
                $code += "  PUSHR 0\n";
            }
            else if(arrType.equals("double")){
                $code += "  PUSHI 2\n";
                $code += "  MUL\n  ADD\n";
                $code += "  PUSHR 0\n";
                $code += push + v.address + "\n";
                $code += $e.code;
                $code += "  PUSHI 2\n";
                $code += "  MUL\n  ADD\n";
                $code += "  PUSHR 1\n";
            }
            $code += $exp.code;
            if( $op.text.equals("+") ) {
                $code += (arrType.equals("double")) ? "  FADD\n" : "  ADD\n";
            } else if( $op.text.equals("-") ) {
                $code += (arrType.equals("double")) ? "  FSUB\n" : "  SUB\n";
            } else if( $op.text.equals("*") ) {
                $code += (arrType.equals("double")) ? "  FMUL\n" : "  MUL\n";
            } else {
                $code += (arrType.equals("double")) ? "  FDIV\n" : "  DIV\n";
            }
            if(!arrType.equals("double"))
                $code += "  STORER 0\n";
            else{
                $code += "  PUSHSP\n";
                $code += "  PUSHR -3\n  PUSHSP\n  PUSHR -2\n  STORER 0\n";
                $code += "  PUSHSP\n";
                $code += "  PUSHR -4\n  PUSHSP\n  PUSHR -3\n  STORER 0\n  FREE 4";
            }    
        }
    | 'input(' id=IDENTIFIANT ')' 
        {
            //VariableInfo v = tablesSymboles.getVar($id.text);
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            Integer deepness = pair.getValue();
            String store = "  STOREL ";
            if(v.scope == VariableInfo.Scope.GLOBAL) {
                store = "  STOREG ";
            }

            if(v.mutable) {
                if(deepness < 1) {
                    if(v.type.equals("int")) {
                        $code = "  READ\n";
                        $code += store + v.address + "\n";
                    } else if(v.type.equals("double")) {
                        $code = "  READF\n";
                        $code += store + (v.address + 1) + "\n";
                        $code += store + v.address + "\n";
                    } else if(v.type.equals("bool")) {
                        $code = "  READ\n";
                        $code += "  PUSHI 0\n";
                        $code += "  NEQ\n";
                        $code += store + v.address + "\n";
                    } else {
                        System.err.println("\nError: Unsupported input type.");
                        System.exit(1);
                    }
                } else {
                    String getting = tablesSymboles.getVarDeep(v, $id.text);
                    
                    if(v.type.equals("int") || v.type.equals("bool")) {
                        $code = getting;
                        $code += "  READ\n";
                        if(v.type.equals("bool")) {
                            $code += "  PUSHI 0\n";
                            $code += "  NEQ\n";
                        }
                        $code += "  STORER " + v.address + "\n";
                    } else {
                        $code = "  READF\n";
                        $code += getting;
                        $code += "  DUP\n";
                        $code += "  PUSHSP\n";
                        $code += "  PUSHR -3\n";
                        $code += "  STORER " + (v.address + 1) +"\n";
                        $code += "  PUSHSP\n";
                        $code += "  PUSHR -3\n";
                        $code += "  STORER " + (v.address) +"\n";
                        $code += "  POP\n  POP\n";
                    }
                }
            } else {
                System.err.println("\nErreur: vous ne pouvez pas modifier une constante");
                System.exit(1);
            }
        }
    | id=IDENTIFIANT (op=('+'|'-'|'*'|'/')'=') exp=expression
        {
            //VariableInfo v = tablesSymboles.getVar($id.text);
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            Integer deepness = pair.getValue();

            if(!v.type.equals($exp.type) || v.type.equals("bool")) {
                System.err.println("Can't assign value of a different type to variable");
                System.exit(1);
            }

            String store = "  STOREL ";
            String push = "  PUSHL ";

            if(v.scope == VariableInfo.Scope.GLOBAL) {
                store = "  STOREG ";
                push = "  PUSHG ";
            }

            if(! v.mutable) {
                System.err.println("\nErreur: vous ne pouvez pas modifier une constante");
                System.exit(1);
            }
            if(!v.type.equals($exp.type)) {
                    System.err.println("Can't assign value of a different type to variable");
                    System.exit(1);
            }
            if(deepness < 1) {
                $code = push + v.address + "\n";
                if(v.type.equals("double")) {
                    $code += push + (v.address + 1) + "\n";
                }
                $code += $exp.code;
                if( $op.text.equals("+") ) {
                    $code += (v.type.equals("double")) ? "  FADD\n" : "  ADD\n";
                } else if( $op.text.equals("-") ) {
                    $code += (v.type.equals("double")) ? "  FSUB\n" : "  SUB\n";
                } else if( $op.text.equals("*") ) {
                    $code += (v.type.equals("double")) ? "  FMUL\n" : "  MUL\n";
                } else {
                    $code += (v.type.equals("double")) ? "  FDIV\n" : "  DIV\n";
                }
                if (v.type.equals("double")) {
                    $code += store + (v.address + 1) + "\n";
                }
                $code += store + v.address + "\n";
            } else {
                
                String getting = tablesSymboles.getVarDeep(v, $id.text);
                    
                if(v.type.equals("int")) {
                    $code = getting;
                    $code += getting;
                    $code += "  PUSHR " + v.address;
                    $code += $exp.code;

                    if( $op.text.equals("+") ) {
                        $code += "  ADD\n";
                    } else if( $op.text.equals("-") ) {
                        $code += "  SUB\n";
                    } else if( $op.text.equals("*") ) {
                        $code += "  MUL\n";
                    } else {
                        $code += "  DIV\n";
                    }

                    $code += "  STORER " + v.address + "\n";
                } else {
                    $code = getting;
                    $code += "  PUSHR " + v.address;
                    $code += getting;
                    $code += "  PUSHR " + (v.address + 1) + "\n";
                    $code += $exp.code;

                    if( $op.text.equals("+") ) {
                        $code += "  FADD\n";
                    } else if( $op.text.equals("-") ) {
                        $code += "  FSUB\n";
                    } else if( $op.text.equals("*") ) {
                        $code += "  FMUL\n";
                    } else {
                        $code += "  FDIV\n";
                    }

                    $code += getting;
                    $code += "  DUP\n";
                    $code += "  PUSHSP\n";
                    $code += "  PUSHR -3\n";
                    $code += "  STORER " + (v.address + 1) +"\n";
                    $code += "  PUSHSP\n";
                    $code += "  PUSHR -3\n";
                    $code += "  STORER " + (v.address) +"\n";
                    $code += "  POP\n  POP\n";
                }
            }
        }
    | id=IDENTIFIANT '=' cdt=condition 
        { 
            //VariableInfo v = tablesSymboles.getVar($id.text);
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            Integer deepness = pair.getValue();
            $code = $cdt.code;
            if(deepness < 1) {
                String store = "  STOREL ";
                if(v.scope == VariableInfo.Scope.GLOBAL)
                    store = "  STOREG ";
                $code += store + v.address + "\n";
            } else {
                String getting = tablesSymboles.getVarDeep(v, $id.text);
                $code = getting;
                $code += $cdt.code;
                $code += "  STORER " + v.address + "\n";
            }
        }
    | 'input(' id=IDENTIFIANT'['exp=expression']'')'
        {
            Pair<VariableInfo, Integer> pair = tablesSymboles.getVar($id.text);
            VariableInfo v = pair.getKey();
            String push = "  PUSHL ";
            String arrType = v.type.substring(0, v.type.length() - 2);
            if(v.scope == VariableInfo.Scope.GLOBAL)
                push = "  PUSHI ";
            if(arrType.equals("int")){ 
                $code = push + v.address + "\n";
                $code += $exp.code;
                $code += "  ADD\n";
                $code += "  READ\n";
                $code += "  STORER 0\n";
            }
            else if(arrType.equals("double")){
                $code = "  READF\n";
                $code += $exp.code;
                $code += "  PUSHI 2\n  MUL\n";
                $code += push + v.address + "\n";
                $code += "  ADD\n";
                $code += "  DUP\n";
                $code += "  PUSHSP\n";
                $code += "  PUSHR -4\n";
                $code += "  STORER 0\n";
                $code += "  PUSHI 1\n  ADD\n";
                $code += "  PUSHSP\n  PUSHR -2\n";
                $code += "  STORER 0\n  POP\n  POP\n";
            }
            else {
                    System.err.println("\nError: Unsupported input type.");
                    System.exit(1);
            }
            
        }
    ;

// -------------------- OutPut (Only Standard output is supported with MVaP)

print returns [ String code ] 
    : 'print(' exp=expression ')' 
        {
            $code = $exp.code;
            if($exp.type.equals("int") || $exp.type.equals("bool"))
                $code += "  WRITE\n  POP\n";
            else if($exp.type.equals("double"))
                $code += "  WRITEF\n  POP\n  POP\n";
            else {
                System.err.println("\nError: Unsupported type to print.");
                System.exit(1);
            }
        }
    | 'print(' c=condition ')' 
        {
            $code = $c.code;
            $code += "  WRITE\n  POP\n";
        }
    ;

bloc returns [ String code ]  
    @init{ $code = new String(); } 
    : '{'
            NEWLINE*
            (instruction { $code += $instruction.code; })*
      '}'
      NEWLINE*
    ;

// -------------------- Conditions

condition returns [String code]
    : 'true'  { $code = "  PUSHI 1\n"; }
    | 'false' { $code = "  PUSHI 0\n"; }
    | '(' condition ')' { $code = $condition.code; }
    | a=expression op=('=='|'!='|'<>'|'<='|'<'|'>='|'>') b=expression 
        { 
            boolean isDouble = false;
            String a = $a.code;
            String b = $b.code;
            if( $a.type.equals("double") ) {
                isDouble = true;
                if( $b.type.equals("int") ) {
                    System.err.println("\nWarning: Implicit cast in condition.");
                    b += "  ITOF\n";
                }
            } else if( $b.type.equals("double") ) {
                isDouble = true;
                if( $a.type.equals("int") ) {
                    System.err.println("\nWarning: Implicit cast in condition.");
                    a += "  ITOF\n";
                }
            }
            $code = $a.code + $b.code;
            if(isDouble)
                $code += "  F";
            else
                $code += "  ";
            $code += getOp($op.text) + "\n";
        }
    | NOT c=condition
        {
            String is1 = getNewLabel() + "_condition\n";
            String end = getNewLabel() + "_condition_end\n";
            $code = $c.code;
            $code += "  JUMPF " + is1;
            $code += "  PUSHI 0\n";
            $code += "  JUMP " + end;
            $code += "LABEL " + is1;
            $code += "  PUSHI 1\n";
            $code += "LABEL " + end;
        }
    | c1=condition AND c2=condition
        {
            String endLabel = getNewLabel() + "_condition_end\n"; 

            $code = $c1.code;
            $code += "  PUSHI 0\n";
            $code += "  NEQ\n";
            $code += "  DUP\n";
            $code += "  JUMPF " + endLabel;
            $code += "  POP\n"; 
            $code += $c2.code;
            $code += "LABEL " + endLabel;

        }
    | c1=condition OR c2=condition
        {
            String c1True = getNewLabel() + "_condition\n";
            String endLabel = getNewLabel() + "_condition_end\n";
            $code = $c1.code;
            $code += "  PUSHI 0\n";
            $code += "  EQUAL\n";
            $code += "  JUMPF " + c1True;
            $code += $c2.code;
            $code += "  JUMP " + endLabel;
            $code += "LABEL " + c1True;
            $code += "  PUSHI 1\n";
            $code += "LABEL " + endLabel;
        }
    | exp=expression
        {
            $code = $exp.code;
            if($exp.type.equals("int")) {
                System.err.println("\nWarning: Implicit cast from int to bool in branchement.");
                $code += "  PUSHI 0\n";
                $code += "  NEQ\n";
            } else if($exp.type.equals("double")) {
                System.err.println("\nWarning: Implicit cast from int to bool in branchement.");
                $code += "  PUSHF 0.0\n";
                $code += "  FNEQ\n";
            }
        }
    ;

// -------------------- Loops (separated to be able to use break and continue in both of them)

loop_while returns [ String code ] 
    @init{
            String start = getNewLabel() + "_loop\n";
            String end = getNewLabel() + "_loop_end\n";

            tablesSymboles.enterLoop(start, end);
    }
    @end{ tablesSymboles.exitLoop(); }
    : 'while' '(' c=condition ')' i=instruction
        {
            $code = "LABEL " + start;
            $code += $c.code;
            $code += "  JUMPF " + end;
            $code += $i.code;
            $code += "  JUMP " + start;
            $code += "LABEL " + end;
        }
    ;

loop_for returns [ String code ]
    @init{
        String start = getNewLabel() + "_loop\n";
        String end = getNewLabel() + "_loop_end\n";
        String assignment = getNewLabel() + "_loop_assign\n";

        tablesSymboles.enterLoop(assignment, end);
    }
    @end{ tablesSymboles.exitLoop(); }
    : 'for' '(' a1=assignation? ';' c=condition? ';' a2=assignation? ')' i=instruction
        {
            $code = $a1.code;
            $code += "LABEL " + start;
            $code += $c.code;
            $code += "  JUMPF " + end;
            $code += $i.code;
            $code += "LABEL " + assignment;
            $code += $a2.code;
            $code += "  JUMP " + start;
            $code += "LABEL " + end;
        }
    ;

// -------------------- If else branchement

if_else returns [ String code ]
    : 'if' '(' c=condition ')' i1=instruction 'else' ie=instruction
        {
            String nextElseLab = getNewLabel() + "_if_else\n";

            String end = getNewLabel() + "_if_else_end\n";

            $code = $c.code;
            $code += "  JUMPF " + nextElseLab;
            
            $code += $i1.code;
            $code += "  JUMP " + end;
            
            $code += "LABEL " + nextElseLab;
            $code += $ie.code;

            $code += "LABEL " + end;

        }
    | 'if' '(' c=condition ')' i1=instruction
        {
            String end = getNewLabel() + "_if_else_end\n";
            $code = $c.code;
            $code += "  JUMPF " + end;
            $code += $i1.code;
            $code += "LABEL " + end;
        }
    ;

// -------------------- Functions

params
    : ((t1=TYPE id1=IDENTIFIANT 
        {   
            tablesSymboles.addParam($id1.text, $t1.text, true);
        })
    | (
        tr=ARRAY_TYPE idr=IDENTIFIANT
        { 
            tablesSymboles.addParam($idr.text, $tr.text, true);
        }
      )
    )    
    ( (',' t2=TYPE id2=IDENTIFIANT
        {
            tablesSymboles.addParam($id2.text, $t2.text, true);
        }
    )
    | (',' t2r=ARRAY_TYPE id2r=IDENTIFIANT
        {
            tablesSymboles.addParam($id2r.text, $t2r.text, true);
        }
    )
    )*
    ;
/* params
    : t1=TYPE id1=IDENTIFIANT
        {   
            tablesSymboles.addParam($id1.text, $t1.text, true);
        }
    ( ',' t2=TYPE id2=IDENTIFIANT
        {
            tablesSymboles.addParam($id2.text, $t2.text, true);
        }
    )*
    ; */

// init nécessaire à cause du ? final et donc args peut être vide (mais $args sera non null) 
args returns [ String code, int size] @init{ $code = new String(); $size = 0; }
    : ( e1=expression
        {
            $code = $e1.code;
            $size = 1;
            if($e1.type.equals("double")) 
                $size += 1;
            // code java pour première expression pour arg
        }
    ( ',' e2=expression
        {
            $code += $e2.code;
            $size += 1;
            if($e2.type.equals("double")) 
                $size += 1;
            // code java pour expression suivante pour arg
        }
    )* )?
    ;

fonction returns [ String code ]
    @init { 
            tablesSymboles.enterBloc();
        } 
    @after { 
            tablesSymboles.exitFunction(); 
            tablesSymboles.exitBloc();
        }
    : type=TYPE id=IDENTIFIANT  
        {
            String lab = tablesSymboles.addFunction($id.text, $type.text);
            if(lab == null) {
                System.err.println("Error was at line " + $id.getLine());
                System.exit(1);
            }
            tablesSymboles.enterFunction();
            //String label = $id.text + "\n";
            $code = "LABEL " + lab + "\n";
            String labelCore = lab + "_core\n";
	    }
    '(' params? ')' '{'
        NEWLINE?
        (decl { $code += $decl.code;} )*
        { $code += "  JUMP " + labelCore; }
        NEWLINE*
        (fonction { $code += $fonction.code;} )*

        NEWLINE*
        { $code += "  LABEL " + labelCore; }
        (instruction { $code += $instruction.code; })*
    '}'

        {
            $code += "RETURN\n";
        }
    NEWLINE*
    ;


// -------------------- Lexer

BOOL : 'bool' ;

CONST : 'const' ;

TYPE : ('int' | BOOL | 'double') ;

ARRAY_TYPE : ('int[]' | 'bool[]' | 'double[]') ;

NEWLINE : ('\r'? '\n')+ ;

finInstruction : ( NEWLINE | ';' )+ ;

RETURN: 'return';

BREAK: 'break';

CONTINUE: 'continue';

WS :   (' '|'\t')+ -> skip ;

IDENTIFIANT 
    :   ('a'..'z' | 'A'..'Z' | '_')('a'..'z' | 'A'..'Z' | '_' | '0'..'9')*
    ;

ENTIER : DIGITS ;

FLOTANT : ( DIGITS '.' DIGITS? ) ;

fragment DIGITS : ('0'..'9')+ ;

NOT : ('!') ;

AND : ('&&') ;

OR : ('||') ;

COMMENT : ((('//' | '%' | '#') ~('\n'|'\r')* ) | ('/*' .*? '*/' )) -> skip ;

UNMATCH : . -> skip ;

