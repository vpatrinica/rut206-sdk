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

#include "board.h"
#include "config.h"
#include "gpio.h"
#include "hal_include.h"

enum gpio_mode {
	GPIO_VALUE_SET_LOW = 0x00,
	GPIO_VALUE_SET_HIGH = 0x01,
	GPIO_VALUE_GET = 0x02,
	GPIO_MODE_SET_OUTPUT = 0x04,
	GPIO_MODE_SET_INPUT = 0x05
};

enum gpio_state {
	GPIO_STATE_HIGH = 0x1E,
	GPIO_STATE_LOW = 0x9F
};

#ifdef TERM_Pin
static int term_state = 0;

enum gs_can_termination_state get_term(can_data_t * channel)
{
	const uint8_t nr = channel->nr;

	if (term_state & (1 << nr)) {
		return GS_CAN_TERMINATION_STATE_ON;
	} else {
		return GS_CAN_TERMINATION_STATE_OFF;
	}
}

enum gs_can_termination_state set_term(can_data_t *channel, enum gs_can_termination_state state)
{
	const uint8_t nr = channel->nr;

	if (state == GS_CAN_TERMINATION_STATE_ON) {
		term_state |= 1 << nr;
	} else {
		term_state &= ~(1 << nr);
	}

	config.termination_set(channel, state);

	return state;
}

#endif

typedef struct {
	GPIO_TypeDef* port;
	uint16_t pin;
} io_pin;


static io_pin g_pins[] = {
	{ .port = GPIOC, .pin = GPIO_PIN_6 },  //  0; PC6
	{ .port = GPIOC, .pin = GPIO_PIN_7 },  //  1; PC7

	{ .port = GPIOA, .pin = GPIO_PIN_4 },  //  2; PA4
	{ .port = GPIOA, .pin = GPIO_PIN_5 },  //  3; PA5
	{ .port = GPIOA, .pin = GPIO_PIN_6 },  //  4; PA6
	{ .port = GPIOA, .pin = GPIO_PIN_7 },  //  5; PA7
	{ .port = GPIOA, .pin = GPIO_PIN_8 },  //  6; PA8
	{ .port = GPIOA, .pin = GPIO_PIN_9 },  //  7; PA9
	{ .port = GPIOA, .pin = GPIO_PIN_10 }, //  8; PA10

	{ .port = GPIOB, .pin = GPIO_PIN_2 },  //  9; PB2
	{ .port = GPIOB, .pin = GPIO_PIN_3 },  // 10; PB3
	{ .port = GPIOB, .pin = GPIO_PIN_4 },  // 11; PB4
	{ .port = GPIOB, .pin = GPIO_PIN_5 },  // 12; PB5
	{ .port = GPIOB, .pin = GPIO_PIN_8 },  // 13; PB8
	{ .port = GPIOB, .pin = GPIO_PIN_9 },  // 14; PB9
	{ .port = GPIOC, .pin = GPIO_PIN_13 }  // 15; PC13 TP31
};

#define GPIO_ARRAY_SIZE sizeof(g_pins) / sizeof(g_pins[0])

void gpio_set_output(uint8_t num) {
	if(num >= GPIO_ARRAY_SIZE) return;
	io_pin *p = &g_pins[num];
	GPIO_InitTypeDef GPIO_InitStruct;
	GPIO_InitStruct.Pin = p->pin;
	GPIO_InitStruct.Mode = GPIO_MODE_OUTPUT_PP;
	GPIO_InitStruct.Pull = GPIO_NOPULL;
	GPIO_InitStruct.Speed = GPIO_SPEED_FREQ_LOW;
	HAL_GPIO_Init(p->port, &GPIO_InitStruct);
}

void gpio_set_value(uint8_t num, bool val) {
	if(num >= GPIO_ARRAY_SIZE) return;
	io_pin *p = &g_pins[num];
	HAL_GPIO_WritePin(p->port, p->pin,
		val ? GPIO_PIN_SET : GPIO_PIN_RESET);
}

uint8_t gpio_get_value(uint8_t num) {
	if(num >= GPIO_ARRAY_SIZE) return 0;
	io_pin *p = &g_pins[num];
	return HAL_GPIO_ReadPin(p->port, p->pin) ?
		GPIO_STATE_HIGH : GPIO_STATE_LOW;
}

void gpio_init() {
	for(uint8_t i=0; i<GPIO_ARRAY_SIZE; i++) {
		gpio_set_value(i, GPIO_VALUE_SET_HIGH);
		gpio_set_output(i);
	}
}

uint8_t gpio_handler(uint8_t *data, uint8_t *ret)
{
	uint8_t num = data[0];
	if(num >= GPIO_ARRAY_SIZE) return 0;

	switch (data[1]) {
	case GPIO_VALUE_SET_LOW:
		gpio_set_value(num, GPIO_VALUE_SET_LOW);
		gpio_set_output(num);
		break;
	case GPIO_VALUE_SET_HIGH:
		gpio_set_value(num, GPIO_VALUE_SET_HIGH);
		gpio_set_output(num);
		break;
	case GPIO_VALUE_GET:
		*ret = gpio_get_value(num);
		return 1;
	case GPIO_MODE_SET_OUTPUT:
		gpio_set_output(num);
		break;
	case GPIO_MODE_SET_INPUT:
		break;
	}
	return 0;
}
