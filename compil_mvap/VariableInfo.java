import java.util.*;

public  class VariableInfo {

    // Enumeration of possible scope for variable 
    public enum Scope {
	    GLOBAL, // Global variable
	    PARAM, // Parameter of a function
	    LOCAL // Local variable (inside a function
    }  
   

    
    public final int address;
    public final String type;
    public final Scope scope;
    public final boolean mutable; // is the variable mutable
    public final int arraySize; // is the variable array

    // Constructor
    public VariableInfo( int a, Scope s, String t, boolean m, int arraySize ){
        this.address = a; // Address of variable
        this.type = t;    // type of variable
	    this.scope = s; // Scope of variable
        this.mutable = m; // Is the variable mutable
        this.arraySize = arraySize;
    }

    /* Get the size of the Variable */
    public static int getSize(String t) {
        if (t.equals("int") || t.equals("bool") || t.equals("int[]") || t.equals("bool[]") || t.equals("double[]")) return 1;
        if (t.equals("double") ) return 2;
        System.err.println("Erreur: type "+ t + " non défini");
        return 0;
    }


    @Override
    public String toString() {
        return "vi:{address:" + this.address +", type:"+ this.type +", mut:"+ this.mutable +", scope:"+this.scope+"}";
    }

}

