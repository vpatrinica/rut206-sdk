/*
 * i2c_slave.c
 *
 *  Created on: Oct 14, 2022
 *      Author: ashirov
 */

#include <stdint.h>
#include <string.h>
#include "gpio.h"
#include "hal_include.h"
#include "i2c_slave.h"
#include "timer.h"

const char fw_version[] __attribute__((section(".fw_version"))) = FW_VERSION;

struct i2c_frame *frm;
uint8_t rx_data_buf[sizeof(struct i2c_frame)];
uint8_t tx_data_buf[64];
uint8_t tx_len = 0;

uint8_t rxcount = 0;

uint8_t gpio_handler(uint8_t *data, uint8_t *ret);

#define STATE_APP_STARTED 252
#define GET_FW_VERSION 0x01
#define CMD_GPIO 0x06
#define CMD_BOOT 0xFE
#define CMD_FW 0xFD

uint8_t fw_handler(uint8_t *data, uint8_t *ret)
{
	switch (data[0]) {
	case GET_FW_VERSION:
		strncpy((char*)&ret[1], fw_version, sizeof(tx_data_buf));
		ret[0] = strlen((const char *)&ret[1]) + 2; // length + version + \0
		return ret[0];
	}
	return 0;
}

void i2c_slave_clear(void){
	memset(frm, 0, sizeof(struct i2c_frame));
	rxcount = 0;
}

void i2c_slave_init(I2C_HandleTypeDef *hi2c){
	frm = (struct i2c_frame *)rx_data_buf;
	i2c_slave_clear();
	HAL_I2C_EnableListen_IT(hi2c);
}

void i2c_slave_check_timeout(I2C_HandleTypeDef *hi2c){

	static int rx_busy_counter = 0;
	static uint32_t old_time_us = 0;
	uint32_t time_us = timer_get();

	if((old_time_us - time_us)<1000) return; // 1ms
	old_time_us = time_us;

	HAL_I2C_StateTypeDef status = 0;

	 status = HAL_I2C_GetState(hi2c);

	  if (status == HAL_I2C_STATE_BUSY_RX_LISTEN){
		  rx_busy_counter++;
	  }
	  else{
		  rx_busy_counter = 0;
	  }

	  if (rx_busy_counter > 100){ // 100ms
		  	HAL_I2C_DisableListen_IT(hi2c);
			HAL_I2C_DeInit(hi2c);
			HAL_I2C_Init(hi2c);
			HAL_I2C_EnableListen_IT(hi2c);
			rx_busy_counter = 0;
	  }
}

void process_frame(void) {
	switch(frm->command) {
		case CMD_BOOT:
			tx_len = 1;
			tx_data_buf[0] = STATE_APP_STARTED;
		break;
		case CMD_GPIO:
			tx_len = gpio_handler(frm->data, &tx_data_buf[0]);
		break;
		case CMD_FW:
			tx_len = fw_handler(frm->data, &tx_data_buf[0]);
		break;
	}
}

void HAL_I2C_AddrCallback(I2C_HandleTypeDef *hi2c, uint8_t TransferDirection, uint16_t AddrMatchCode){
	UNUSED(AddrMatchCode);
	if(TransferDirection == I2C_DIRECTION_TRANSMIT){  // master transmit STM receive
		rxcount = 0;
		HAL_I2C_Slave_Seq_Receive_IT(hi2c, rx_data_buf, 1, I2C_FIRST_FRAME);
	}else{
		rxcount = 0;
		if(!tx_len) tx_len = 1;
		HAL_I2C_Slave_Seq_Transmit_IT(hi2c, tx_data_buf, tx_len, I2C_LAST_FRAME);
	}
}

void HAL_I2C_SlaveRxCpltCallback(I2C_HandleTypeDef *hi2c){
	uint8_t len = frm->length + 2;
	rxcount++;
	if (rxcount < len){
		if(rxcount == len-1)
		{
			HAL_I2C_Slave_Seq_Receive_IT(hi2c, rx_data_buf + rxcount, 1, I2C_LAST_FRAME);
		}
		else
		{
			HAL_I2C_Slave_Seq_Receive_IT(hi2c, rx_data_buf + rxcount, 1, I2C_NEXT_FRAME);
		}
		return;
	}
	if (rxcount == len){
		process_frame();
		i2c_slave_clear();
		HAL_I2C_EnableListen_IT(hi2c);
	}
}

void HAL_I2C_ListenCpltCallback (I2C_HandleTypeDef *hi2c){
	HAL_I2C_EnableListen_IT(hi2c);
}

void HAL_I2C_SlaveTxCpltCallback(I2C_HandleTypeDef *hi2c){
	HAL_I2C_EnableListen_IT(hi2c);
}

void HAL_I2C_ErrorCallback(I2C_HandleTypeDef *hi2c)
{
	//HAL_I2C_ERROR_NONE       0x00000000U    /*!< No error           */
	//HAL_I2C_ERROR_BERR       0x00000001U    /*!< BERR error         */
	//HAL_I2C_ERROR_ARLO       0x00000002U    /*!< ARLO error         */
	//HAL_I2C_ERROR_AF         0x00000004U    /*!< Ack Failure error  */
	//HAL_I2C_ERROR_OVR        0x00000008U    /*!< OVR error          */
	//HAL_I2C_ERROR_DMA        0x00000010U    /*!< DMA transfer error */
	//HAL_I2C_ERROR_TIMEOUT    0x00000020U    /*!< Timeout Error      */
	uint32_t error_code = HAL_I2C_GetError(hi2c);
	if (error_code == HAL_I2C_ERROR_AF){}
	else if (error_code == HAL_I2C_ERROR_BERR){
 		HAL_I2C_DeInit(hi2c);
    	HAL_I2C_Init(hi2c);
		i2c_slave_clear();
	}
	HAL_GPIO_TogglePin(GPIOC, GPIO_PIN_13);
	HAL_I2C_EnableListen_IT(hi2c);
}

