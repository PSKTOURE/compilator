Nous avons tout fait jusqu'à 'autres amélioration" (dont nous en avons fait plusieurs).

Autres améliorations réalisée:
	- support raisonnable pour les flotants (on permet certains cast implicite avec Warning en plus du support minimal)
	- cast
	- certains cast raisonnable avec Warning
	- Des Warning et Error gentil pour les humains (pas partout pour l'instant)
	- type bool

Réalisations bonus:
	- opérateurs logiques optimisés
	- expressions pré/post dé/incrémentation ( --i, ++i, i--, i++)
	- assignations avec -=, *=, /=
	- variables locales par blocs et non simplement par fonction
	- Libération des variables globales à la fin du main
	- variable locales y compris possible dans le main avec des blocs (d'où le CALL Main et non le jump Main)
