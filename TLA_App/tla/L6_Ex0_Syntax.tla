--------------------------- MODULE L6_Ex0_Syntax ---------------------------
(***************************************************************************)
(* Лекция 6. Пример 0. «Песочница» синтаксиса: множества, кванторы,         *)
(* функции (словари), EXCEPT, CHOOSE.                                       *)
(*                                                                         *)
(* Как это работает: TLC при запуске один раз вычисляет каждую строку      *)
(* ASSUME. PrintT(x) печатает значение x и возвращает TRUE.                *)
(* Значит, каждая строка ниже — это «console.log» для формулы TLA+.        *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets, TLC

CONSTANT Procs          \* в .cfg: Procs = {p1, p2, p3} (model values, как enum)

VARIABLE x              \* фиктивная переменная: TLC нужна хоть какая-то модель
Init == x = 0
Next == UNCHANGED x

-----------------------------------------------------------------------------
\* ЧАСТЬ 1. МНОЖЕСТВА (неупорядоченные, без повторов, как HashSet)

S == {1, 2, 3}
T == {3, 4}

ASSUME PrintT(<<"01. S", S>>)
ASSUME PrintT(<<"02. {1,1,2} = {2,1}", {1, 1, 2} = {2, 1}>>)      \* порядок и повторы не важны
ASSUME PrintT(<<"03. 2 in S", 2 \in S>>)
ASSUME PrintT(<<"04. 5 notin S", 5 \notin S>>)
ASSUME PrintT(<<"05. S union T", S \union T>>)                    \* объединение   (Union)
ASSUME PrintT(<<"06. S intersect T", S \intersect T>>)            \* пересечение   (Intersect)
ASSUME PrintT(<<"07. S minus T", S \ T>>)                         \* разность      (Except)
ASSUME PrintT(<<"08. Cardinality(S)", Cardinality(S)>>)           \* размер        (Count)
ASSUME PrintT(<<"09. 1..5", 1..5>>)                               \* диапазон      (Range)
ASSUME PrintT(<<"10. filter: even", {n \in 1..10 : n % 2 = 0}>>)  \* фильтр        (Where)
ASSUME PrintT(<<"11. map: squares", {n * n : n \in 1..4}>>)       \* отображение   (Select)
ASSUME PrintT(<<"12. SUBSET {1,2}", SUBSET {1, 2}>>)              \* все подмножества
ASSUME PrintT(<<"13. BOOLEAN", BOOLEAN>>)                         \* {FALSE, TRUE}

-----------------------------------------------------------------------------
\* ЧАСТЬ 2. КВАНТОРЫ (\A = «для всех», \E = «существует»)

ASSUME PrintT(<<"14. A n in S : n > 0", \A n \in S : n > 0>>)     \* S.All(n => n > 0)
ASSUME PrintT(<<"15. E n in S : n > 2", \E n \in S : n > 2>>)     \* S.Any(n => n > 2)
ASSUME PrintT(<<"16. E n in S : n > 9", \E n \in S : n > 9>>)
ASSUME PrintT(<<"17. all pairs <<p, q>>", {<<p, q>> : p \in {1, 2}, q \in {1, 2}}>>)

-----------------------------------------------------------------------------
\* ЧАСТЬ 3. МНОЖЕСТВО ПРОЦЕССОВ (model values из .cfg)

ASSUME PrintT(<<"18. Procs", Procs>>)
ASSUME PrintT(<<"19. Procs minus {p1}", Procs \ {CHOOSE p \in Procs : TRUE}>>)

-----------------------------------------------------------------------------
\* ЧАСТЬ 4. ФУНКЦИИ = СЛОВАРИ (Dictionary<Proc, string>)

pc == [p \in Procs |-> "idle"]                      \* каждому процессу — "idle"

ASSUME PrintT(<<"20. pc", pc>>)                      \* TLC печатает как (p1 :> "idle" @@ ...)
ASSUME PrintT(<<"21. DOMAIN pc", DOMAIN pc>>)        \* ключи словаря

\* EXCEPT: «копия словаря, где по одному ключу лежит новое значение»
pc2 == [pc EXCEPT ![CHOOSE p \in Procs : TRUE] = "cs"]

ASSUME PrintT(<<"22. pc2 (one proc in cs)", pc2>>)
ASSUME PrintT(<<"23. who is in cs", {p \in Procs : pc2[p] = "cs"}>>)
ASSUME PrintT(<<"24. how many in cs", Cardinality({p \in Procs : pc2[p] = "cs"})>>)

\* Множество ВСЕХ словарей Procs -> BOOLEAN (используется в TypeOK)
ASSUME PrintT(<<"25. |[Procs -> BOOLEAN]|", Cardinality([Procs -> BOOLEAN])>>)

\* Запись (record) — словарь со строковыми ключами
acc == [id |-> 1, balance |-> 100]
ASSUME PrintT(<<"26. acc.balance", acc.balance>>)

-----------------------------------------------------------------------------
\* ЧАСТЬ 5. CHOOSE — «возьми какой-нибудь (детерминированно один и тот же)»

Other(p) == CHOOSE q \in {1, 2} : q # p
ASSUME PrintT(<<"27. Other(1)", Other(1)>>)
ASSUME PrintT(<<"28. Other(2)", Other(2)>>)

=============================================================================
