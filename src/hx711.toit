// Copyright (C) 2021 Toitware ApS.  All rights reserved.
// Use of this source code is governed by an MIT-style license that can be
// found in the LICENSE file.

import gpio
import uart

/**
Driver for the HX711 Analog-to-Digital converter.
*/

/**
An argument to the constructor of $Hx711.
Valid instances are $Hx711.CHANNEL_A_GAIN_128, $Hx711.CHANNEL_B_GAIN_32, or
  $Hx711.CHANNEL_A_GAIN_64.
*/
class Hx711Input:
  pulses/int

  constructor.private_ .pulses:

/**
Driver for the HX711 Analog-to-Digital converter.
Uses a UART to form the correct shaped pulses.
This driver does not currently support power-down mode for the chip.
*/
class Hx711:
  data_/gpio.Pin := ?
  uart_port_/uart.Port := ?
  input_/Hx711Input? := null

  /// Read from channel A with a gain of 128.
  static CHANNEL_A_GAIN_128/Hx711Input ::= Hx711Input.private_ 25
  /// Read from channel B with a gain of 32.
  static CHANNEL_B_GAIN_32/Hx711Input  ::= Hx711Input.private_ 26
  /// Read from channel A with a gain of 64.
  static CHANNEL_A_GAIN_64/Hx711Input  ::= Hx711Input.private_ 27

  /**
  The $clock pin is used as an output pin, connected to the UART hardware.
  The $data pin is used as an input GPIO pin.
  */
  constructor --clock/gpio.Pin --data/gpio.Pin:
    data.configure --input
    data_ = data
    uart_port_ = uart.Port
      --tx=clock
      --rx=null
      // This common baud rate gives an 8.6us pulse for each start bit, which is
      // in the range of 0.1us to 50us that the HX711 requires.
      --baud_rate=115200
      // We want the idle state to be low and the start bit to be high.
      --invert_tx=true

  // The actual pattern on the UART TX pin will be a start bit (high,
  // 8.6us), eight data bits (low, since the TX pin is inverted) and a stop bit
  // (low).
  SINGLE_PULSE_ := #[0xff]

  /**
  Returns a value between -1.0 and 1.0.
  May also return -Infinity or Infinity if the measurement is out of range.
  For $input pass $Hx711.CHANNEL_A_GAIN_128, $Hx711.CHANNEL_B_GAIN_32, or
    $Hx711.CHANNEL_A_GAIN_64.
  */
  get input/Hx711Input -> float:
    writer := uart_port_.out
    if input_ != input:
      // If the input setting is wrong we do a dummy read to set the input
      // correctly.
      data_.wait_for 0
      input.pulses.repeat:
        writer.write SINGLE_PULSE_
        sleep --ms=1
      input_ = input

    // Wait for a sample to be ready.
    data_.wait_for 0

    measurement := 0

    24.repeat:
      writer.write SINGLE_PULSE_
      sleep --ms=1
      measurement <<= 1
      bit := data_.get
      measurement |= bit

    // The number of pulses (25 to 27) determines the input setting of the next
    // reading.
    (input_.pulses - 24).repeat:
      writer.write SINGLE_PULSE_
      sleep --ms=1

    if measurement == 0x7f_ffff: return float.INFINITY
    if measurement == 0x80_0000: return -float.INFINITY
    if measurement < 0x80_0000: return measurement.to_float / 0x80_0000
    return (measurement - 0x100_0000).to_float / 0x80_0000

  /**
  Takes 10 samples, discarding infinities unless there are a lot of
    infinities, in which case it returns positive or negative infinity.
  Discards outliers using the method of removing elements that are further
    from the mean than 1.5 interquartile ranges.  Returns the mean of the
    non-discarded samples.
  For $input pass $Hx711.CHANNEL_A_GAIN_128, $Hx711.CHANNEL_B_GAIN_32, or
    $Hx711.CHANNEL_A_GAIN_64.
  */
  average_of_10 input/Hx711Input -> num:
    while true:
      infinities := 0
      samples := []
      while samples.size < 10:
        measurement := get input
        if -float.INFINITY < measurement < float.INFINITY:
          samples.add measurement
        else:
          infinities++
          if infinities > 20: return measurement
          samples = []
      while true:
        assert: samples.size >= 2
        new_samples := remove_outlier_ samples
        if new_samples.size == samples.size:
          return mean_ samples
        samples = new_samples

  median_ l/List:
    if l.size == 0: throw "Too few data points"
    sorted := l.sort
    if sorted.size & 1 == 0:
      // Even number of elements.  Eg. if there are 6 then take the average of
      // sorted[2] and sorted[3].
      return (sorted[sorted.size / 2 - 1] + sorted[sorted.size / 2]) / 2.0
    else:
      // Odd number of elements.  Eg. if there are 3 then return sorted[1].
      return sorted[(sorted.size - 1) / 2]

  interquartile_range_ l/List:
    if l.size < 2: throw "Too few data points"
    sorted := l.sort
    s := sorted.size
    if s & 1 == 0:
      // Even number of elements.
      q1 := median_ sorted[..s / 2]
      q3 := median_ sorted[s / 2..]
      return q3 - q1
    else:
      // Odd number of elements.
      q1 := median_ sorted[..(s - 1) / 2]
      q3 := median_ sorted[(s + 1) / 2..]
      return q3 - q1

  mean_ l/List:
    mean := (l.reduce: | a b | a + b) / l.size
    return mean

  remove_outlier_ l/List -> List:
    removed := false
    result := []
    iqr := interquartile_range_ l
    mn := mean_ l
    l.do:
      if removed:
        result.add it
      else:
        difference := (it - mn).abs
        if difference > 1.5 * iqr:
          removed = true
        else:
          result.add it
    return result
