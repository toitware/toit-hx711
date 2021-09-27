// Copyright (C) 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the EXAMPLES_LICENSE file.

import hx711 show Hx711
import gpio

main:
  hx711 := Hx711 --clock=17 --data=16

  while true:
    print "Sampled:  $(hx711.get Hx711.CHANNEL_A_GAIN_64)"
    print "Averaged: $(hx711.average_of_10 Hx711.CHANNEL_A_GAIN_64)"
