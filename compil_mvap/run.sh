#!/bin/bash


make

java -cp "/usr/share/java/*:MVaP.jar" MVaPAssembler t2.mvap  

#java -jar MVaP.jar -d t2.mvap.cbap
java -jar MVaP.jar t2.mvap.cbap
