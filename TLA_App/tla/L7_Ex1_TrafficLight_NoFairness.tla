------------------- MODULE L7_Ex1_TrafficLight_NoFairness -------------------
(***************************************************************************)
(* Лекция 7. Пример 1 (без справедливости). Светофор.                      *)
(*                                                                         *)
(*   red -> green -> yellow -> red -> ...                                  *)
(*                                                                         *)
(* Safety («ничего плохого»):  светофор никогда не прыгает с red на yellow. *)
(* Liveness («что-то хорошее»): красный КОГДА-НИБУДЬ сменится зелёным.     *)
(*                                                                         *)
(* Ожидание: TypeOK и SafeTransition выполняются, а RedLeadsToGreen        *)
(* НАРУШЕНО. TLC печатает трассу, которая заканчивается словом             *)
(* «Stuttering»: светофор просто «завис» на красном. Формула               *)
(* Init /\ [][Next]_vars РАЗРЕШАЕТ системе бесконечно стоять на месте.     *)
(***************************************************************************)

VARIABLE light

vars == <<light>>

Colors == {"red", "green", "yellow"}

TypeOK == light \in Colors

Init == light = "red"

ToGreen  == light = "red"    /\ light' = "green"
ToYellow == light = "green"  /\ light' = "yellow"
ToRed    == light = "yellow" /\ light' = "red"

Next == ToGreen \/ ToYellow \/ ToRed

\* [Next]_vars  ==  Next \/ UNCHANGED vars   <- шаг «на месте» (stuttering) разрешён
Spec == Init /\ [][Next]_vars

-----------------------------------------------------------------------------
\* ---------- SAFETY: оператор [] («всегда») ----------
\* «Всегда: если сейчас красный, то в следующем состоянии красный или зелёный».
\* (light' — значение в СЛЕДУЮЩЕМ состоянии; [][A]_light — каждый шаг либо A, либо light не менялся)
SafeTransition == [][light = "red" => light' = "green"]_light

\* ---------- LIVENESS: операторы <> («когда-нибудь») и ~> («приводит к») ----------
EventuallyGreen      == <>(light = "green")            \* хоть раз станет зелёным
InfinitelyOftenGreen == []<>(light = "green")          \* зелёный будет снова и снова
RedLeadsToGreen      == (light = "red") ~> (light = "green")  \* == [](red => <>green)

=============================================================================

