open Base
open Hardcaml
open Hardcaml_arty

module Waveform = Hardcaml_waveterm.Waveform

let clock = Signal.input "clock" 1

let%expect_test "tx_state_machine" =
  let valid = Signal.input "valid" 1 in
  let value = Signal.input "value" 8 in
  let clear = Signal.input "clear" 1 in
  let uart_tx =
    Signal.output 
      "uart_tx"
      (Uart.Expert.create_tx_state_machine ~clear ~clock ~cycles_per_bit:4 { valid; value })
  in
  let circuit = Circuit.create_exn ~name:"tx_state_machine" [ uart_tx ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create
      (Cyclesim.create ~config:Cyclesim.Config.trace_all circuit) in
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "valid") := Bits.vdd;
  (Cyclesim.in_port sim "value") := Bits.of_int ~width:8 0b01010111;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "valid") := Bits.gnd;
  for _ = 0 to 40 do
    Cyclesim.cycle sim;
  done;
  Waveform.print ~display_width:100 ~display_height:25 ~wave_width:(-1) waves;
  [%expect{|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────┐
    │clock             ││╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥│
    │                  ││╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨│
    │clear             ││                                                                              │
    │                  ││────────────────────────────────────────────                                  │
    │valid             ││  ┌┐                                                                          │
    │                  ││──┘└────────────────────────────────────────                                  │
    │                  ││──┬─────────────────────────────────────────                                  │
    │value             ││ .│57                                                                         │
    │                  ││──┴─────────────────────────────────────────                                  │
    │uart_tx           ││───┐   ┌───────────┐   ┌───┐   ┌───┐   ┌────                                  │
    │                  ││   └───┘           └───┘   └───┘   └───┘                                      │
    │                  ││───────────┬───┬───┬───┬───┬───┬───┬───┬────                                  │
    │tx_byte_cnt       ││ 0         │1  │2  │3  │4  │5  │6  │7  │0                                     │
    │                  ││───────────┴───┴───┴───┴───┴───┴───┴───┴────                                  │
    │                  ││───┬───┬───────────────────────────────┬───┬                                  │
    │tx_state          ││ 0 │1  │2                              │3  │                                  │
    │                  ││───┴───┴───────────────────────────────┴───┴                                  │
    │vdd               ││────────────────────────────────────────────                                  │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    └──────────────────┘└──────────────────────────────────────────────────────────────────────────────┘ |}]
;;

let%expect_test "rx_state_machine" =
  let clear = Signal.input "clear" 1 in
  let uart_rx_raw = Signal.input "uart_rx_raw" 1 in
  let uart_rx =
    (Uart.Expert.create_rx_state_machine ~clear ~clock ~cycles_per_bit:4 uart_rx_raw)
  in
  let valid = Signal.output "valid" uart_rx.valid in
  let value = Signal.output "value" uart_rx.value in
  let circuit = Circuit.create_exn ~name:"rx_state_machine" [ valid; value ] in
  let waves, sim = Hardcaml_waveterm.Waveform.create (Cyclesim.create ~config:Cyclesim.Config.trace_all circuit) in
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
  Waveform.print ~display_height:30 ~display_width:100 ~wave_width:(-1)
    waves;
  [%expect {|
    decoded 00110101

    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────┐
    │clock             ││╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥│
    │                  ││╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨│
    │clear             ││                                                                              │
    │                  ││───────────────────────────────────────────────                               │
    │uart_rx_raw       ││──┐   ┌───┐   ┌───┐   ┌───────┐       ┌────────                               │
    │                  ││  └───┘   └───┘   └───┘       └───────┘                                       │
    │valid             ││                                          ┌┐                                  │
    │                  ││──────────────────────────────────────────┘└───                               │
    │                  ││──────────┬───┬───┬───┬───┬───┬───┬───┬────────                               │
    │value             ││ 00       │80 │40 │A0 │50 │A8 │D4 │6A │35                                     │
    │                  ││──────────┴───┴───┴───┴───┴───┴───┴───┴────────                               │
    │gnd               ││                                                                              │
    │                  ││───────────────────────────────────────────────                               │
    │                  ││───────────┬───┬───┬───┬───┬───┬───┬───┬───────                               │
    │rx_byte_cnt       ││ 0         │1  │2  │3  │4  │5  │6  │7  │0                                     │
    │                  ││───────────┴───┴───┴───┴───┴───┴───┴───┴───────                               │
    │                  ││───┬───┬───────────────────────────────┬───┬───                               │
    │rx_state          ││ 0 │1  │2                              │3  │0                                 │
    │                  ││───┴───┴───────────────────────────────┴───┴───                               │
    │vdd               ││───────────────────────────────────────────────                               │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    │                  ││                                                                              │
    └──────────────────┘└──────────────────────────────────────────────────────────────────────────────┘ |}]

let%expect_test "loopback" =
  let circuit =
    let clock = Signal.input "clock" 1 in
    let clear = Signal.input "clear" 1 in
    let uart_rx_raw = Signal.input "uart_rx" 1 in
    let uart_rx_byte =
      Uart.Expert.create_rx_state_machine ~clear ~clock ~cycles_per_bit:4
        uart_rx_raw
    in
    let uart_tx_raw =
      Uart.Expert.create_tx_state_machine
        ~clock ~clear
        ~cycles_per_bit:4
        { valid = uart_rx_byte.valid; value = uart_rx_byte.value }
    in
    Circuit.create_exn ~name:"rx_state_machine"
      [ Signal.output  "uart_tx" uart_tx_raw ]
  in
  let waves, sim =
    Hardcaml_waveterm.Waveform.create
      (Cyclesim.create ~config:Cyclesim.Config.trace_all circuit)
  in
  Cyclesim.cycle sim;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "clear") := Bits.vdd;
  Cyclesim.cycle sim;
  (Cyclesim.in_port sim "clear") := Bits.gnd;

  List.iter ([ 0 ] @ [ 1; 0; 1; 0; 1; 1; 0; 0; ] @ [ 1 ]) ~f:(fun bit ->
      (Cyclesim.in_port sim "uart_rx") := (
        if bit = 0 then Bits.gnd else Bits.vdd);
      Cyclesim.cycle sim;
      Cyclesim.cycle sim;
      Cyclesim.cycle sim;
      Cyclesim.cycle sim);
  for _ = 0 to 45 do
    Cyclesim.cycle sim;
  done;
  Waveform.print ~display_width:120 ~display_height:25 ~wave_width:(-1) waves;
  [%expect {|
    ┌Signals───────────┐┌Waves─────────────────────────────────────────────────────────────────────────────────────────────┐
    │clock             ││╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥╥│
    │                  ││╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨╨│
    │clear             ││  ┌┐                                                                                              │
    │                  ││──┘└─────────────────────────────────────────────────────────────────────────────────────         │
    │uart_rx           ││       ┌───┐   ┌───┐   ┌───────┐       ┌─────────────────────────────────────────────────         │
    │                  ││───────┘   └───┘   └───┘       └───────┘                                                          │
    │uart_tx           ││────────────────────────────────────────────┐   ┌───┐   ┌───┐   ┌───────┐       ┌────────         │
    │                  ││                                            └───┘   └───┘   └───┘       └───────┘                 │
    │gnd               ││                                                                                                  │
    │                  ││─────────────────────────────────────────────────────────────────────────────────────────         │
    │                  ││────────────┬───┬───┬───┬───┬───┬───┬───┬────────────────────────────────────────────────         │
    │rx_byte_cnt       ││ 0          │1  │2  │3  │4  │5  │6  │7  │0                                                        │
    │                  ││────────────┴───┴───┴───┴───┴───┴───┴───┴────────────────────────────────────────────────         │
    │                  ││─┬─┬┬───┬───────────────────────────────┬───┬────────────────────────────────────────────         │
    │rx_state          ││ │1││1  │2                              │3  │0                                                    │
    │                  ││─┴─┴┴───┴───────────────────────────────┴───┴────────────────────────────────────────────         │
    │                  ││────────────────────────────────────────────────────┬───┬───┬───┬───┬───┬───┬───┬────────         │
    │tx_byte_cnt       ││ 0                                                  │1  │2  │3  │4  │5  │6  │7  │0                │
    │                  ││────────────────────────────────────────────────────┴───┴───┴───┴───┴───┴───┴───┴────────         │
    │                  ││────────────────────────────────────────────┬───┬───────────────────────────────┬───┬────         │
    │tx_state          ││ 0                                          │1  │2                              │3  │0            │
    │                  ││────────────────────────────────────────────┴───┴───────────────────────────────┴───┴────         │
    │vdd               ││─────────────────────────────────────────────────────────────────────────────────────────         │
    └──────────────────┘└──────────────────────────────────────────────────────────────────────────────────────────────────┘ |}]
;;
