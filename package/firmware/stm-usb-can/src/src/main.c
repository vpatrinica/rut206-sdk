/*

The MIT License (MIT)

Copyright (c) 2016 Hubert Denkmair

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

#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "board.h"
#include "can.h"
#include "can_common.h"
#include "config.h"
#include "device.h"
#include "dfu.h"
#include "gpio.h"
#include "gs_usb.h"
#include "hal_include.h"
#include "led.h"
#include "timer.h"
#include "usbd_conf.h"
#include "usbd_core.h"
#include "usbd_def.h"
#include "usbd_desc.h"
#include "usbd_gs_can.h"
#include "i2c_slave.h"
#include "util.h"
#include "stm32g0xx.h"

void HAL_MspInit(void);
void HAL_I2C_MspInit(I2C_HandleTypeDef *hi2c);
void Error_Handler(void);

static void SystemClock_Config(void);
static void Fix_Boot0_Pin(void);
static void MX_I2C1_Init(void);
static void MX_IWDG_Init(void);

I2C_HandleTypeDef hi2c1;
IWDG_HandleTypeDef hiwdg;
static USBD_GS_CAN_HandleTypeDef hGS_CAN;
static USBD_HandleTypeDef hUSB = { 0 };

int main(void)
{
	Fix_Boot0_Pin();
	HAL_Init();
	SystemClock_Config();
	MX_I2C1_Init();
	MX_IWDG_Init();
	config.setup(&hGS_CAN);
	timer_init();

	INIT_LIST_HEAD(&hGS_CAN.list_frame_pool);
	INIT_LIST_HEAD(&hGS_CAN.list_to_host);

	i2c_slave_init(&hi2c1);

	for (unsigned i = 0; i < ARRAY_SIZE(hGS_CAN.msgbuf); i++) {
		list_add_tail(&hGS_CAN.msgbuf[i].list,
			      &hGS_CAN.list_frame_pool);
	}

	for (unsigned int i = 0; i < ARRAY_SIZE(hGS_CAN.channels); i++) {
		const struct BoardChannelConfig *channel_config =
			&config.channels[i];
		const struct LEDConfig *led_config = channel_config->leds;
		can_data_t *channel		   = &hGS_CAN.channels[i];

		channel->nr = i;

		INIT_LIST_HEAD(&channel->list_from_host);

		led_init(&channel->leds, led_config[LED_RX].port,
			 led_config[LED_RX].pin, led_config[LED_RX].active_high,
			 led_config[LED_TX].port, led_config[LED_TX].pin,
			 led_config[LED_TX].active_high);

		/* nice wake-up pattern */
		for (uint8_t j = 0; j < 10; j++) {
			HAL_GPIO_TogglePin(led_config[LED_RX].port,
					   led_config[LED_RX].pin);
			HAL_Delay(50);
			HAL_GPIO_TogglePin(led_config[LED_TX].port,
					   led_config[LED_TX].pin);
		}

		led_set_mode(&channel->leds, LED_MODE_OFF);

		can_init(channel, config.channels[i].interface);
		can_disable(channel);
	}

	USBD_Init(&hUSB, (USBD_DescriptorsTypeDef *)&FS_Desc, DEVICE_FS);
	USBD_RegisterClass(&hUSB, &USBD_GS_CAN);
	USBD_GS_CAN_Init(&hGS_CAN, &hUSB);
	USBD_Start(&hUSB);

	while (1) {
		for (unsigned int i = 0; i < ARRAY_SIZE(hGS_CAN.channels);
		     i++) {
			can_data_t *channel = &hGS_CAN.channels[i];

			CAN_SendFrame(&hGS_CAN, channel);
		}

		USBD_GS_CAN_ReceiveFromHost(&hUSB);
		USBD_GS_CAN_SendToHost(&hUSB);

		for (unsigned int i = 0; i < ARRAY_SIZE(hGS_CAN.channels);
		     i++) {
			can_data_t *channel = &hGS_CAN.channels[i];

			CAN_ReceiveFrame(&hGS_CAN, channel);
			CAN_HandleError(&hGS_CAN, channel);

			led_update(&channel->leds);
		}

		if (USBD_GS_CAN_DfuDetachRequested(&hUSB)) {
			dfu_run_bootloader();
		}
		i2c_slave_check_timeout(&hi2c1);

		HAL_IWDG_Refresh(&hiwdg);
	}
}

void HAL_MspInit(void)
{
	__HAL_RCC_SYSCFG_CLK_ENABLE();
	__HAL_RCC_PWR_CLK_ENABLE();

	HAL_PWREx_ControlVoltageScaling(PWR_REGULATOR_VOLTAGE_SCALE1);
	HAL_NVIC_SetPriority(SysTick_IRQn, 0, 0);
}

static void MX_IWDG_Init(void)
{
	hiwdg.Instance	     = IWDG;
	hiwdg.Init.Prescaler = IWDG_PRESCALER_32;
	hiwdg.Init.Reload    = 1000; // reload value for ~1 seconds timeout
	hiwdg.Init.Window    = 1000;

	if (HAL_IWDG_Init(&hiwdg) != HAL_OK) {
		Error_Handler();
	}
}

static void MX_I2C1_Init(void)
{
	hi2c1.Instance		    = I2C1;
	hi2c1.Init.Timing	    = 0x00D09BE3;
	hi2c1.Init.OwnAddress1	    = 234;
	hi2c1.Init.AddressingMode   = I2C_ADDRESSINGMODE_7BIT;
	hi2c1.Init.DualAddressMode  = I2C_DUALADDRESS_DISABLE;
	hi2c1.Init.OwnAddress2	    = 0;
	hi2c1.Init.OwnAddress2Masks = I2C_OA2_NOMASK;
	hi2c1.Init.GeneralCallMode  = I2C_GENERALCALL_DISABLE;
	hi2c1.Init.NoStretchMode    = I2C_NOSTRETCH_DISABLE;
	if (HAL_I2C_Init(&hi2c1) != HAL_OK) {
		Error_Handler();
	}

	/** Configure Analogue filter
  */
	if (HAL_I2CEx_ConfigAnalogFilter(&hi2c1, I2C_ANALOGFILTER_ENABLE) !=
	    HAL_OK) {
		Error_Handler();
	}

	/** Configure Digital filter
  */
	if (HAL_I2CEx_ConfigDigitalFilter(&hi2c1, 0) != HAL_OK) {
		Error_Handler();
	}
}

static void Fix_Boot0_Pin(void)
{
	/* check for the BOOT0 selection to avoid reflashing */
	if ((FLASH->OPTR & FLASH_OPTR_nBOOT_SEL) == 0) {
		/* nBOOT_SEL is already cleared..., do nothing */
		return;
	}

	/* Clear the LOCK bit in FLASH->CR (precondition for option byte flash) */
	FLASH->KEYR = 0x45670123;
	FLASH->KEYR = 0xCDEF89AB;
	/* Clear the OPTLOCK bit in FLASH->CR */
	FLASH->OPTKEYR = 0x08192A3B;
	FLASH->OPTKEYR = 0x4C5D6E7F;

	/* Enable legacy mode (BOOT0 bit defined by BOOT0 pin) */
	/* by clearing the nBOOT_SELection bit */
	FLASH->OPTR &= ~FLASH_OPTR_nBOOT_SEL;

	/* check if there is any flash operation */
	while ((FLASH->SR & FLASH_SR_BSY1) != 0)
		;

	/* start the option byte flash */
	FLASH->CR |= FLASH_CR_OPTSTRT;
	/* wait until flashing is done */
	while ((FLASH->SR & FLASH_SR_BSY1) != 0)
		;

	/* do a busy delay, for about one second, check BSY1 flag to avoid compiler loop optimization */
	for (unsigned long i = 0; i < 2000000; i++)
		if ((FLASH->SR & FLASH_SR_BSY1) != 0)
			break;

	/* load the new value and do a system reset */
	/* this will behave like a goto to the begin of this main procedure */
	FLASH->CR |= FLASH_CR_OBL_LAUNCH;

	/* we will never arrive here */
	for (;;)
		;
}

void SystemClock_Config(void)
{
	device_sysclock_config();
}

void Error_Handler(void)
{
	/* USER CODE BEGIN Error_Handler_Debug */
	/* User can add his own implementation to report the HAL error return state */
	__disable_irq();
	while (1) {
	}
	/* USER CODE END Error_Handler_Debug */
}

void _close_r(void)
{
}

void _lseek_r(void)
{
}

void _read_r(void)
{
}

void _write_r(void)
{
}