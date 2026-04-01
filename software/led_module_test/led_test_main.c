//*****************************************************************************
//*****************************    C Source Code    ****************************
//*****************************************************************************
//  DESIGNER NAME:  Eli Bell
//
//       PROJECT:  CSC202 Expansion Board Test Program
//
//      FILE NAME:  led_test_main.c
//
//-----------------------------------------------------------------------------
//
// DESCRIPTION:
//    This program runs on the LP_MSPM0G3507 LaunchPad and interfaces with a
//    custom CSC202 Expansion PCB.
//
//    The expansion board contains:
//      - An 8-channel LED bar
//      - A 4-digit 7-segment hexadecimal display
//
//    Both peripherals can be controlled through two selectable hardware modes:
//      1. SPI Mode:
//         Data is shifted into an external shift register via SPI and latched
//         using a chip select (CS) signal.
//      2. GPIO Mode:
//         Data is driven directly over an 8-bit parallel bus through a
//         non-inverting buffer.
//
//    A physical switch on the PCB selects between SPI and GPIO control paths.
//    This software updates BOTH paths regardless of switch position so that
//    either mode is immediately functional when toggled.
//
//    The program performs a "walking bit" test pattern:
//      - A single '1' bit shifts left across all outputs
//      - Then shifts back right
//      - Repeats for both LED bar and 7-segment display
//
//    For the 7-segment display:
//      - Each loop iteration updates a different digit index
//      - This demonstrates multiplexing across all digits
//
//    This test verifies:
//      - SPI communication and latch timing
//      - GPIO parallel output functionality
//      - Buffer and shift register hardware correctness
//      - LED and 7-segment display operation
//
//*****************************************************************************
//*****************************************************************************

//-----------------------------------------------------------------------------
// Loads standard C include files
//-----------------------------------------------------------------------------
#include <stdio.h>

//-----------------------------------------------------------------------------
// Loads MSP launchpad board support macros and definitions
//-----------------------------------------------------------------------------
#include "LaunchPad.h"
#include "clock.h"
#include "spi.h"
#include <ti/devices/msp/msp.h>

//-----------------------------------------------------------------------------
// Define symbolic constants used by the program
//-----------------------------------------------------------------------------

#define BAUD_RATE (115200) // UART debug (unused here)

#define SPI_CONFIG_DELAY (50) // Delay for SPI latch timing (ms)

#define WALK_TEST_REPEAT_COUNT (4) // Number of sweep repetitions

#define ON_TIME (100) // Delay between pattern updates (ms)

//-----------------------------------------------------------------------------
// Define global variables and structures here.
// NOTE: when possible avoid using global variables
//-----------------------------------------------------------------------------

// Mode selection for which peripheral to actively drive via GPIO
typedef enum
{
    LEDS, // Drive LED bar via GPIO
    SEG7, // Drive 7-segment display via GPIO
} Mode;

//-----------------------------------------------------------------------------
// Define function prototypes used by the program
//-----------------------------------------------------------------------------

void walk_test(Mode mode);
void update(uint8_t data, Mode mode, uint8_t seg7_idx);

//-----------------------------------------------------------------------------
// Main Function
//-----------------------------------------------------------------------------
int main(void)
{
    // System initialization
    clock_init_40mhz();
    launchpad_gpio_init();

    // Peripheral initialization
    leds_init();
    leds_disable(); // Start with LEDs off
    seg7_init();
    spi1_init();

    // Configure SPI Chip Select (CS) as GPIO for manual control
    IOMUX->SECCFG.PINCM[LP_SPI_CS0_IOMUX] =
        IOMUX_PINCM_PC_CONNECTED | PINCM_GPIO_PIN_FUNC;
    GPIOB->DOE31_0 |= LP_SPI_CS0_MASK;   // Set as output
    GPIOB->DOUT31_0 &= ~LP_SPI_CS0_MASK; // Initialize low

    // Main loop: continuously test both modes
    while (1)
    {
        walk_test(LEDS);
        walk_test(SEG7);
    }
}

//-----------------------------------------------------------------------------
// walk_test
//
// DESCRIPTION:
//    Performs a walking-bit test pattern on the selected output mode.
//
//    The pattern:
//      - Shifts a single '1' bit from LSB → MSB
//      - Then shifts back MSB → LSB
//
//    For SEG7 mode:
//      - Cycles through digit indices to demonstrate multiplexing
//
// PARAMETERS:
//    mode - LEDS or SEG7
//-----------------------------------------------------------------------------
void walk_test(Mode mode)
{
    uint8_t data;
    uint8_t seg7_idx;

    // Enable/disable LED buffer depending on mode
    switch (mode)
    {
    case LEDS:
        leds_enable(); // Enable LED GPIO path
        break;

    case SEG7:
        leds_disable(); // Prevent LED contention
        break;
    }

    for (uint8_t loop_count = 0; loop_count < WALK_TEST_REPEAT_COUNT;
         loop_count++)
    {
        // Cycle through 7-segment digits
        seg7_idx = loop_count % MAX_NUM_SEG7_DISPLAYS;

        data = 1;

        // Shift left across outputs
        uint8_t led_idx = 0;
        for (; led_idx < MAX_NUM_LEDS - 1; led_idx++)
        {
            update(data, mode, seg7_idx);
            data = data << 1;
        }

        // Shift right back across outputs
        for (led_idx = MAX_NUM_LEDS; led_idx > 1; led_idx--)
        {
            update(data, mode, seg7_idx);
            data = data >> 1;
        }
    }

    // Turn off outputs at end of test
    data = 1;
    update(data, mode, seg7_idx);
    update(--data, mode, seg7_idx); // clears output
}

//-----------------------------------------------------------------------------
// update
//
// DESCRIPTION:
//    Updates both SPI and GPIO output paths with the given data.
//
//    Operation:
//      1. Disable 7-segment display to avoid ghosting
//      2. Send inverted data over SPI to shift register
//      3. Toggle chip select (CS) to latch data
//      4. Drive selected output via GPIO (LED or 7-seg)
//      5. Wait for visible persistence
//
// PARAMETERS:
//    data      - 8-bit pattern to display
//    mode      - LEDS or SEG7
//    seg7_idx  - Active 7-segment digit index
//-----------------------------------------------------------------------------
void update(uint8_t data, Mode mode, uint8_t seg7_idx)
{
    uint8_t recv = 0;

    // Turn off display before updating (prevents ghosting)
    seg7_off();

    // Send data to shift register (SPI path)
    spi1_write_data(~data);  // Inverted due to hardware wiring
    recv = spi1_read_data(); // Dummy read (optional/debug)

    // Latch SPI data using CS pulse
    GPIOB->DOUT31_0 |= LP_SPI_CS0_MASK;
    msec_delay(SPI_CONFIG_DELAY);
    GPIOB->DOUT31_0 &= ~LP_SPI_CS0_MASK;

    // Drive GPIO path based on selected mode
    switch (mode)
    {
    case LEDS:
        leds_on(data);
        break;

    case SEG7:
        seg7_on(data, seg7_idx);
        break;
    }

    // Hold output for visibility
    msec_delay(ON_TIME);
}