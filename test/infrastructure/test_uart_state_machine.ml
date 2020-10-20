open Base
open Hardcaml
open Hardcaml_arty

module Waveform = Hardcaml_waveterm.Waveform

let clock = Signal.input "clock" 1

let%expect_test "tx_state_machine" =
  let valid = Signal.input "valid" 1 in
  let value = Signal.input "value" 8 in
  let uart_tx =
    Signal.output 
      "uart_tx"
      (Uart.Expert.create_tx_state_machine ~clock ~cycles_per_bit:1 { valid; value })
  in
  let circuit = Circuit.create_exn ~name:"tx_state_machine" [ uart_tx ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create circuit) in
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "valid") := Bits.vdd;
  (Cyclesim.in_port sim "value") := Bits.of_int ~width:8 0b01010111;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "valid") := Bits.gnd;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  Waveform.print ~display_width:80 ~wave_width:1 waves;
  [%expect {|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────┐
    │clock             ││┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─┐ ┌─│
    │                  ││  └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ └─┘ │
    │valid             ││        ┌───┐                                             │
    │                  ││────────┘   └───────────────────────────────────────────  │
    │                  ││────────┬───────────────────────────────────────────────  │
    │value             ││ 00     │57                                               │
    │                  ││────────┴───────────────────────────────────────────────  │
    │uart_tx           ││────────────┐   ┌───────────┐   ┌───┐   ┌───┐   ┌───────  │
    │                  ││            └───┘           └───┘   └───┘   └───┘         │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    └──────────────────┘└──────────────────────────────────────────────────────────┘ |}]
;;

let%expect_test "rx_state_machine" =
  let uart_rx_raw = Signal.input "uart_rx_raw" 1 in
  let uart_rx =
    (Uart.Expert.create_rx_state_machine ~clock ~cycles_per_bit:4 uart_rx_raw)
  in
  let valid = Signal.output "valid" uart_rx.valid in
  let value = Signal.output "value" uart_rx.value in
  let circuit = Circuit.create_exn ~name:"rx_state_machine" [ valid; value ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create ~is_internal_port:(Fn.const true) circuit) in
  let valid = Cyclesim.out_port ~clock_edge:Before sim "valid" in
  let value = Cyclesim.out_port ~clock_edge:Before sim "value" in
  let cycle () =
    Cyclesim.cycle sim;
    if Bits.is_vdd !valid then (
      Stdio.printf "decoded %s\n\n" (Bits.to_string !value)
    );
  in
  let start_bits = [ 0 ] in
  let data_bits = [ 1; 0; 1; 0; 1; 1; 0; 0; ] in
  let stop_bits = [ 1 ] in
  let uart_rx_raw = (Cyclesim.in_port sim "uart_rx_raw") in
  uart_rx_raw := Bits.vdd;
  cycle ();
  cycle ();
  List.iter (start_bits @ data_bits @ stop_bits) ~f:(fun bit ->
      uart_rx_raw := (if bit = 1 then Bits.vdd else Bits.gnd);
      cycle ();
      cycle ();
      cycle ();
      cycle ();
    );
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  cycle ();
  Waveform.print ~display_width:80 ~wave_width:(-1) waves;
  [%expect {|
    decoded 00110101

    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────┐
    │clock             ││╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥│
    │                  ││╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨│
    │uart_rx_raw       ││──┐   ┌───┐   ┌───┐   ┌───────┐       ┌────────           │
    │                  ││  └───┘   └───┘   └───┘       └───────┘                   │
    │valid             ││                                          ┌┐              │
    │                  ││──────────────────────────────────────────┘└───           │
    │                  ││──────────┬───┬───┬───┬───┬───┬───┬───┬────────           │
    │value             ││ 00       │80 │40 │A0 │50 │A8 │D4 │6A │35                 │
    │                  ││──────────┴───┴───┴───┴───┴───┴───┴───┴────────           │
    │gnd               ││                                                          │
    │                  ││───────────────────────────────────────────────           │
    │                  ││───┬───┬───────────────────────────────┬┬──┬───           │
    │state             ││ 0 │1  │2                              ││4 │0             │
    │                  ││───┴───┴───────────────────────────────┴┴──┴───           │
    │vdd               ││───────────────────────────────────────────────           │
    │                  ││                                                          │
    │                  ││                                                          │
    │                  ││                                                          │
    └──────────────────┘└──────────────────────────────────────────────────────────┘ |}]
