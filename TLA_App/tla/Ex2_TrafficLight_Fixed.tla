---------------------- MODULE Ex2_TrafficLight_Fixed ----------------------
(***************************************************************************)
(* Пример 2 (Исправленный вариант). Светофор на перекрёстке.               *)
(* Решение: добавлены охранные условия (Guards).                           *)
(* Зелёный свет включается ТОЛЬКО если второй светофор УЖЕ красный.        *)
(***************************************************************************)

VARIABLES 
    lightNS,    \* Сигнал светофора Север-Юг: "red" или "green"
    lightEW     \* Сигнал светофора Восток-Запад: "red" или "green"

vars == <<lightNS, lightEW>>

Init ==
    /\ lightNS = "green"
    /\ lightEW = "red"

\* Включить зелёный на Север-Юг: разрешено ТОЛЬКО если Восток-Запад красный!
TurnGreenNS ==
    /\ lightEW = "red"          \* Охранное условие (Guard)
    /\ lightNS = "red"
    /\ lightNS' = "green"
    /\ UNCHANGED lightEW

\* Переключить Север-Юг на красный
TurnRedNS ==
    /\ lightNS = "green"
    /\ lightNS' = "red"
    /\ UNCHANGED lightEW

\* Включить зелёный на Восток-Запад: разрешено ТОЛЬКО если Север-Юг красный!
TurnGreenEW ==
    /\ lightNS = "red"          \* Охранное условие (Guard)
    /\ lightEW = "red"
    /\ lightEW' = "green"
    /\ UNCHANGED lightNS

\* Переключить Восток-Запад на красный
TurnRedEW ==
    /\ lightEW = "green"
    /\ lightEW' = "red"
    /\ UNCHANGED lightNS

Next == 
    \/ TurnGreenNS 
    \/ TurnRedNS 
    \/ TurnGreenEW 
    \/ TurnRedEW

-----------------------------------------------------------------------------
TypeOK ==
    /\ lightNS \in {"red", "green"}
    /\ lightEW \in {"red", "green"}

\* ИНВАРИАНТ БЕЗОПАСНОСТИ:
SafetyNoCrash ==
    ~ (lightNS = "green" /\ lightEW = "green")

===========================================================================
