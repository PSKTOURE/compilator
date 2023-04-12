import java.util.*;

class Pair<K, V> {

    private final K element0;
    private final V element1;

    public static <K, V> Pair<K, V> createPair(K element0, V element1) {
        return new Pair<K, V>(element0, element1);
    }

    public Pair(K element0, V element1) {
        this.element0 = element0;
        this.element1 = element1;
    }

    public K getKey() {
        return element0;
    }

    public V getValue() {
        return element1;
    }

}

/** 
 * 3 Tables des symboles :
 *     _ Une table pour les variables globales; 
 *     _ Une pour les paramètres;
 *     _ une pour les variables locales.
 *
 *     Chaque table donne pour chaque variable sa position (son adresse dans la pile).
 *     On recherche d'abord en local puis en paramètre si défini.
 *     Comme on manipule des variables typées, on stocke également le type et le scope.
 *
 *     On utlise ici des tables de hachage stockant des objets VariableInfo
 *
 *     Pour autoriser un fonction et une variable de même nom, on ajoute aussi :
 *     _ Une Table des étiquettes des fonctions.
 *
 *     Note : une pile de tables pourrait être nécessaire,
 *       si on voulait pouvoir définir des fonctions dans des fonctions...
 *
 *    Et on conserve la dernière fonction ajoutée pour savoir le type de la valeur de retour
 */
class TablesSymboles {

    private TableSimple _tableGlobale = new TableSimple(); // Table des variables globales 
    //private TableSimple _tableParam = null; // Table des paramêtres
	private LinkedList<TableSimple> _tablesParams = new LinkedList<>(); // Table des paramêtres
	private LinkedList<TableSimple> _tablesLocales = new LinkedList<>(); 

	private LinkedList<HashMap<String, Pair<String, String> >> _tablesFonctions = new LinkedList<>();
	//private LinkedList<Integer> _fonctionsLayers =

	//private HashMap<String, String> _tableFonction = new HashMap<String, String>(); // Table des fonctions 

	private LinkedList<LinkedList<String>> _tableLoopStart = new LinkedList<>();
	private LinkedList<LinkedList<String>> _tableLoopEnd = new LinkedList<>();

	private LinkedList<String> _returnsType = new LinkedList<>();
    //private String _returnType = null;

	private LinkedList<Integer> _fonction_indices = new LinkedList<>();

	public TablesSymboles() {
		_tableLoopStart.addFirst(new LinkedList<>());
		_tableLoopEnd.addFirst(new LinkedList<>());
		_tablesFonctions.addFirst(new HashMap<>());
		//_tablesParams.addFirst();
		_fonction_indices.addFirst(0);
	}
    /* 
     * Partie pour la création / cloture des tables locale
     * À faire lors de l’entrée ou la sortie d’une fonction
     */

    // Créer les tables locales pour les variables dans une fonction
    public void enterFunction() {
		_tablesFonctions.addFirst(new HashMap<>());
		_tablesParams.addFirst(new TableSimple());
		//_tableParam = new TableSimple();
		_tableLoopStart.addFirst(new LinkedList<>());
		_tableLoopEnd.addFirst(new LinkedList<>());
		_fonction_indices.addFirst(0);
    }
	
	public void enterBloc() {
		//_tableLocale = new TableSimple();
		_tablesLocales.addFirst(new TableSimple());
	}

    // Détruire les tables locales des variables à la sortie d’une fonction
    public void exitFunction() { 
        //_tableParam = null;
		_tablesParams.removeFirst();
		_tableLoopStart.removeFirst();
		_tableLoopEnd.removeFirst();
		_fonction_indices.removeFirst();
		Integer last = _fonction_indices.peek();
		_fonction_indices.removeFirst();
		_fonction_indices.addFirst( last + 1 );
		_tablesFonctions.removeFirst();
    }

	public void exitBloc() { 
		//_tableLocale = null;
		_tablesLocales.removeFirst();
	}


	// for break and continue implementation
	public void enterLoop(String labelStart, String labelEnd) {
		_tableLoopStart.peek().addFirst(labelStart);
		_tableLoopEnd.peek().addFirst(labelEnd);
	}

	public void exitLoop() {
		_tableLoopStart.peek().removeFirst();
		_tableLoopEnd.peek().removeFirst();
	}

	public String getCurrentLoopStart() {
		return _tableLoopStart.peek().peek();
	}

	public String getCurrentLoopEnd() {
		return _tableLoopEnd.peek().peek();
	}


    // Connaitre la taille occupée par les variables locales
    public int getVariableLocalSize() {
	    if ( _tablesLocales.size() == 0) {
		 System.err.println("Erreur: Impossible de connaître la taille des variables locales car les tables locales ne sont pas initialisées");
		 return 0;
	    }
	    return _tablesLocales.peek().getSize();
    }

	
	// Connaitre la taille occupée par les variables globales
    public int getVariableGlobaleSize() {
		return  _tableGlobale.getSize();
    }


    /* 
     * Partie pour l’ajout ou la récupération de variable et paramètres
     */

	public void addVarDecl(String name, String t, boolean mutable) {
		addVarDecl(name, t, mutable, 0);
    }

	 // Ajouter une nouvelle variable Locale ou globale
    public void addVarDecl(String name, String t, boolean mutable, int arraySize) {
		if ( _tablesLocales.size() == 0 ) { // On regarde si on est à l’extérieur d’une fonction
			// On a une variable globale
			_tableGlobale.addVar(name, VariableInfo.Scope.GLOBAL, t, mutable, arraySize);
		} else {
			// On a une variable locale 
			_tablesLocales.peek().addVar(name, VariableInfo.Scope.LOCAL, t, mutable, arraySize);
		}
    }

    // Ajouter un paramètre de fonction
    public void addParam(String name, String t, boolean mutable) {
        if ( _tablesParams.size() == 0 ) {
			System.err.println("Erreur: Impossible d’ajouter la variable "+name+
			 "car les tables locales ne sont pas initialisées");
	 	} else { 
			_tablesParams.peek().addVar(name, VariableInfo.Scope.PARAM, t, mutable);
	 	}
    }

	// Ajouter un paramètre de fonction (avec ArraySize)
    public void addParam(String name, String t, boolean mutable, int arraySize) {
        if ( _tablesParams.size() == 0 ) {
	       	System.err.println("Erreur: Impossible d’ajouter la variable "+name+
			"car les tables locales ne sont pas initialisées");
		} else { 
            _tablesParams.peek().addVar(name, VariableInfo.Scope.PARAM, t, mutable, arraySize);
        }
    }

    // Récupérer les infos d’une variable (ou d’un paramètre)
    public Pair<VariableInfo, Integer>  getVar(String name) {
		if ( _tablesLocales.size() != 0 ) {  
			// On cherche d’abord parmi les variables locales
			int counter = 0;
			for( TableSimple tl : _tablesLocales ) {
				VariableInfo vi = tl.getVariableInfo(name);
				if (vi != null) 
					return new Pair<>(new VariableInfo( vi.address, vi.scope, vi.type, vi.mutable, vi.arraySize), counter); // On a trouvé
				counter += 1;
			}
		}
		if ( _tablesParams.size() != 0 ) {
			// On cherche ensuite parmi les paramètres
			int counter = 0;
			for(TableSimple tp : _tablesParams) {
				VariableInfo vi = tp.getVariableInfo(name);
				if (vi != null) {
					return new Pair<>(new VariableInfo( 
						vi.address - (tp.getSize() + 2),
						// On calcule l’adresse du paramètre
						vi.scope,
						vi.type,
						vi.mutable,
						vi.arraySize
						), counter);	
				}
				counter += 1;
			}
		}
		// Enfin, on cherche parmi les variables globales
		VariableInfo vi = _tableGlobale.getVariableInfo(name);
		if (vi != null) {
			return new Pair<>(new VariableInfo(vi.address, vi.scope, vi.type, vi.mutable, vi.arraySize), -1);
		}
		System.err.println("## Erreur : la variable \"" + name + "\" n'existe pas");
		return null; // Attention: ceci ne doit pas arriver et va probablement faire planter le programme
    }

	public String getVarDeep(VariableInfo v, String name) {
		//String name = v.name;
		String res = ""; //"  PUSHL -3";
		int counter = 0;
		LinkedList<TableSimple> table = (v.scope == VariableInfo.Scope.PARAM) ? _tablesParams : _tablesLocales;
		for(TableSimple t : table) {
			VariableInfo vi = t.getVariableInfo(name);
			if(vi != null) {
				return res; // remains the PUSHR vi.address
			}
			if(counter ++ == 0) {
				res += "  PUSHL -1\n";
			} else {
				res += "  PUSHR -1\n";
			}
		}
		System.err.println("Error: Not supposed to happen (in getVarDeep)");
		return null;
	}

    // Récupérer l’adresse de la valeur de retour
    //  Note: Cette fonction ne doit être appelé qu’après avoir déclarer les paramètres
    public VariableInfo getReturn() {
		if ( _tablesParams.size() == 0 ) {
			System.err.println("Erreur: Impossible de calculer l’emplacement"+
			" de la valeur de retour car les tables locales"+
				" ne sont pas initialisées");
			return null;  // Attention: ceci ne doit pas arriver et va probablement faire planter le programme
		}
		return  new VariableInfo(
				 - (_tablesParams.peek().getSize() + 2 + VariableInfo.getSize(_returnsType.peek())), // On calcule l’adresse du paramètre
				 VariableInfo.Scope.PARAM, 
				 _returnsType.peek(),
				 true, 0); // haven't done that part yet so I will consider the variable to be mutable
    }


    /* 
     * Partie pour les fonctions 
     *
     */
    public Pair<String, String> getFunction(String function) {
		for(HashMap<String, Pair<String, String> > tf : _tablesFonctions) {
			Pair<String, String> l = tf.get(function);
			if (l != null)
			    return l;
		}
		System.err.println("Appel à une fonction non définie \""+function+"\"");
		return null;
    }

    public String addFunction(String function,String type) {
        Pair<String, String> fat = _tablesFonctions.peek().get(function);
		if ( fat != null ) {
	    	System.err.println("Fonction \""+ function + 
				    "\" déjà définie avec type de retour \"" + fat +"\".");
	    	return null;
		}
		_returnsType.addFirst(type);
		
		String lab = function;
		for(Integer i :  _fonction_indices) {
			lab += "_" + i;
		}

		_tablesFonctions.peek().put(function, new Pair<>(lab, type) );
		
		return lab;
    }

}
    
