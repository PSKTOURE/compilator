#!/bin/bash

# NOTE pour nos benchmarks: Avoir un fichier BMs qui suit la même archi que le prof
# puis faire : PREF_COR="${PREF_COR:-/usr/share/tp-compil-autocor/BMs}" avec notre truc

LANG=en_US.utf8 tp-compil-autocor Calculette.g4 VariableInfo.java TableSimple.java TablesSymboles.java