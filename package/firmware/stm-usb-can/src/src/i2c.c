#include "hal_include.h"

void Error_Handler(void);

/* @brief I2C MSP Initialization
  * This function configures the hardware resources
  * @param hi2c: I2C handle pointer
  * @retval None
  */
void HAL_I2C_MspInit(I2C_HandleTypeDef *hi2c)
{
	GPIO_InitTypeDef GPIO_InitStruct       = { 0 };
	RCC_PeriphCLKInitTypeDef PeriphClkInit = { 0 };
	if (hi2c->Instance == I2C1) {

		PeriphClkInit.PeriphClockSelection = RCC_PERIPHCLK_I2C1;
		PeriphClkInit.I2c1ClockSelection   = RCC_I2C1CLKSOURCE_PCLK1;
		if (HAL_RCCEx_PeriphCLKConfig(&PeriphClkInit) != HAL_OK) {
			Error_Handler();
		}

		__HAL_RCC_GPIOB_CLK_ENABLE();
		/**I2C1 GPIO Configuration
        PB6     ------> I2C1_SCL
        PB7     ------> I2C1_SDA
        */
		GPIO_InitStruct.Pin	  = GPIO_PIN_6 | GPIO_PIN_7;
		GPIO_InitStruct.Mode	  = GPIO_MODE_AF_OD;
		GPIO_InitStruct.Pull	  = GPIO_PULLUP;
		GPIO_InitStruct.Speed	  = GPIO_SPEED_FREQ_VERY_HIGH;
		GPIO_InitStruct.Alternate = GPIO_AF6_I2C1;
		HAL_GPIO_Init(GPIOB, &GPIO_InitStruct);

		/* Peripheral clock enable */
		__HAL_RCC_I2C1_CLK_ENABLE();
		/* I2C1 interrupt Init */
		HAL_NVIC_SetPriority(I2C1_IRQn, 0, 0);
		HAL_NVIC_EnableIRQ(I2C1_IRQn);
	}
}

/**
  * @brief I2C MSP De-Initialization
  * This function freeze the hardware resources
  * @param hi2c: I2C handle pointer
  * @retval None
  */
void HAL_I2C_MspDeInit(I2C_HandleTypeDef *hi2c)
{
	if (hi2c->Instance == I2C1) {
		/* Peripheral clock disable */
		__HAL_RCC_I2C1_CLK_DISABLE();

		/**I2C1 GPIO Configuration
        PB6     ------> I2C1_SCL
        PB7     ------> I2C1_SDA
        */
		HAL_GPIO_DeInit(GPIOB, GPIO_PIN_6);
		HAL_GPIO_DeInit(GPIOB, GPIO_PIN_7);

		/* I2C1 interrupt DeInit */
		HAL_NVIC_DisableIRQ(I2C1_IRQn);
	}
}
