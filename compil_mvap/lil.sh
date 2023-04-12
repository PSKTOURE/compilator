#!/bin/bash

export CLASSPATH=.:"/usr/share/java/*":$CLASSPATH
antlr4 Calculette.g4
#javac VariableInfo.java
#javac TableSimple.java
#javac TablesSymboles.java
#javac Calculette*.java
javac *.java

# antlr4-grun Calculette 'calcul' #-gui