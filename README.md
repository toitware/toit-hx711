# HX711

A driver for the HX711 analog-to-digital converter often used for scales.

This is a 24 bit D-to-A that uses a unique two-wire protocol with a clock
and a data line.

Keeping the clock high too long will cause a reset, which means it is somewhat
timing sensitive.  This driver uses the UART circuitry to make sure the high
clock pulses are not too long.  The time between the high clock pulses is not
as critical.

# Example

```
import hx711 show Hx711
import gpio

main:
  hx711 := Hx711 --clock=17 --data=16

  while true:
    print "Sampled:  $(hx711.get Hx711.CHANNEL_A_GAIN_64)"
    print "Averaged: $(hx711.average_of_10 Hx711.CHANNEL_A_GAIN_64)"
```
