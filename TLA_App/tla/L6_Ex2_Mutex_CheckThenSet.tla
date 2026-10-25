--------------------- MODULE L6_Ex2_Mutex_CheckThenSet ---------------------
(***************************************************************************)
(* Лекция 6. Пример 2. Попытка №1 сделать замок (mutex) из флагов.         *)
(*                                                                         *)
(*   while (flag[other]) { }   // 1. ПРОВЕРИЛ: «туалет свободен?»          *)
(*   flag[me] = true;          // 2. ЗАНЯЛ:    «повесил табличку»          *)
(*   ... критическая секция ...                                            *)
(*   flag[me] = false;         // 3. ОСВОБОДИЛ                             *)
(*                                                                         *)
(* Ожидание: MutualExclusion НАРУШЕН (это снова TOCTOU из лекции 5).       *)
(***************************************************************************)
EXTENDS Naturals, FiniteSets     \* Naturals нужен для "<=", FiniteSets — для Cardinality

CONSTANT Procs

VARIABLES
    flag,                       \* flag[p] = TRUE  <=> p «повесил табличку Занято»
    pc                          \* pc[p] : "idle" | "set" | "cs"

vars == <<flag, pc>>

TypeOK ==
    /\ flag \in [Procs -> BOOLEAN]
    /\ pc   \in [Procs -> {"idle", "set", "cs"}]

Init ==
    /\ flag = [p \in Procs |-> FALSE]
    /\ pc   = [p \in Procs |-> "idle"]

\* 1. Проверка: ни у кого другого нет флага (иначе действие запрещено = «ждём»)
Check(p) ==
    /\ pc[p] = "idle"
    /\ \A q \in Procs \ {p} : flag[q] = FALSE
    /\ pc' = [pc EXCEPT ![p] = "set"]
    /\ UNCHANGED flag

\* 2. Поднимаем свой флаг и входим в критическую секцию
SetAndEnter(p) ==
    /\ pc[p] = "set"
    /\ flag' = [flag EXCEPT ![p] = TRUE]
    /\ pc'   = [pc   EXCEPT ![p] = "cs"]

\* 3. Выходим и опускаем флаг
Exit(p) ==
    /\ pc[p] = "cs"
    /\ flag' = [flag EXCEPT ![p] = FALSE]
    /\ pc'   = [pc   EXCEPT ![p] = "idle"]

Next == \E p \in Procs : Check(p) \/ SetAndEnter(p) \/ Exit(p)

-----------------------------------------------------------------------------
\* ВЗАИМНОЕ ИСКЛЮЧЕНИЕ: никакие два РАЗНЫХ процесса не в КС одновременно
MutualExclusion ==
    \A p, q \in Procs : (p # q) => ~(pc[p] = "cs" /\ pc[q] = "cs")

\* То же самое через множества: «в КС не больше одного»
InCS == {p \in Procs : pc[p] = "cs"}
MutualExclusion2 == Cardinality(InCS) <= 1

=============================================================================
