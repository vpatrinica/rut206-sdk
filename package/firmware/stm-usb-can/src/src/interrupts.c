/*

The MIT License (MIT)

Copyright (c) 2019 Hubert Denkmair

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

#include <stdint.h>
#include "hal_include.h"

extern I2C_HandleTypeDef hi2c1;

void NMI_Handler(void)
{
	__asm__ ("BKPT");
	while (1);
}

void HardFault_Handler(void)
{
	__asm__ ("BKPT");
	while (1);
}

void SysTick_Handler(void)
{
	HAL_IncTick();
	HAL_SYSTICK_IRQHandler();
}

extern PCD_HandleTypeDef hpcd_USB_FS;
void USB_Handler(void)
{
	HAL_PCD_IRQHandler(&hpcd_USB_FS);
}

void Default_Handler(void)
{
	__asm__ ("BKPT");
	while (1);
}

void I2C1_IRQHandler(void)
{
  if (hi2c1.Instance->ISR & (I2C_FLAG_BERR | I2C_FLAG_ARLO | I2C_FLAG_OVR))
  {
    HAL_I2C_ER_IRQHandler(&hi2c1);
  }
  else
  {
    HAL_I2C_EV_IRQHandler(&hi2c1);
  }
}

extern void Reset_Handler(void);

typedef void (*pFunc)(void);
extern uint32_t __StackTop;

__attribute__((used, section(".vectors")))
const pFunc InterruptVectorTable[48] = {
	(pFunc)(&__StackTop), // initial stack pointer
	Reset_Handler,        // reset handler
	NMI_Handler,          // -14: NMI
	HardFault_Handler,    // -13: HardFault
	0,                    // -12: MemManage_Handler
	0,                    // -11: BusFault_Handler
	0,                    // -10: UsageFault_Handler
	0,                    //
	0,                    //
	0,                    //
	0,                    //
	0,                    // -5: SVC_Handler
	0,                    // -4: DebugMon_Handler
	0,                    //
	0,                    // -2: PendSV
	SysTick_Handler,      // -1: SysTick
// External Interrupts
	0,                    /* Window WatchDog              */
	0,                    /* PVD through EXTI Line detect */
	0,                    /* RTC through the EXTI line    */
	0,                    /* FLASH                        */
	0,                    /* RCC & CRS                    */
	0,                    /* EXTI Line 0 and 1            */
	0,                    /* EXTI Line 2 and 3            */
	0,                    /* EXTI Line 4 to 15            */
	USB_Handler,          /* USB, UCPD1, UCPD2            */
	0,                    /* DMA1 Channel 1               */
	0,                    /* DMA1 Channel 2 and Channel 3 */
	0,                    /* DMA1 Ch4 to Ch7, DMA2 Ch1 to Ch5, DMAMUX1 overrun */
	0,                    /* ADC1, COMP1 and COMP2         */
	0,                    /* TIM1 Break, Update, Trigger and Commutation */
	0,                    /* TIM1 Capture Compare         */
	0,                    /* TIM2                         */
	0,                    /* TIM3, TIM4                   */
	0,                    /* TIM6, DAC and LPTIM1         */
	0,                    /* TIM7 and LPTIM2              */
	0,                    /* TIM14                        */
	0,                    /* TIM15                        */
	0,                    /* TIM16 & FDCAN1_IT0 & FDCAN2_IT0 */
	0,                    /* TIM17 & FDCAN1_IT1 & FDCAN2_IT1 */
	I2C1_IRQHandler,      /* I2C1                         */
	0,                    /* I2C2, I2C3                   */
	0,                    /* SPI1                         */
	0,                    /* SPI2, SPI3                   */
	0,                    /* USART1                       */
	0,                    /* USART2 & LPUART2             */
	0,                    /* USART3, USART4, USART5, USART6, LPUART1   */
	0,                    /* CEC                          */
	// don't need to define any interrupts after this one
};

