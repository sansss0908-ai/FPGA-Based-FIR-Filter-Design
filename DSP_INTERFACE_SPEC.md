# DSP & FIR Filter Hardware Interface Specification

## 1. System Parameters
* **Sampling Frequency ($F_s$):** $500\text{ Hz}$ ($\Delta t = 2\text{ ms}$)
* **Passband Edge ($F_p$):** $20\text{ Hz}$
* **Stopband Cutoff ($F_s$):** $50\text{ Hz}$
* **Filter Architecture:** Low-pass Equiripple FIR Filter

## 2. Data Representation & Fixed-Point Format
* **Input Signal Data Type:** 16-bit Signed 2's Complement Integer (`int16_t`)
* **Scale Factor:** $1\text{ g} = 16384 \text{ LSB}$ ($\pm 2\text{g}$ full scale)
* **Coefficient Format:** Q15 Signed Fixed-Point ($1\text{ sign bit}, 15\text{ fractional bits}$)
  $$\text{Coeff}_{\text{Q15}} = \text{round}(h[n] \times 32768)$$

## 3. Communication Protocol (STM32 $\rightarrow$ FPGA)
* **Bus:** SPI Master (Mode 0, MSB First, $2.625\text{ MBits/s}$)
* **Frame Structure:** 2 Bytes per sample (`{MSB, LSB}`)