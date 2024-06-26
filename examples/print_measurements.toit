// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import hx711 show Hx711
import gpio

CLOCK ::= gpio.Pin 17
DATA  ::= gpio.Pin 16

main:
  hx711 := Hx711 --clock=CLOCK --data=DATA

  while true:
    print "Sampled:  $(hx711.get Hx711.CHANNEL-A-GAIN-64)"
    print "Averaged: $(hx711.average-of-10 Hx711.CHANNEL-A-GAIN-64)"
