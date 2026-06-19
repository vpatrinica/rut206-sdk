#ifndef STM_GPIO_IO_H
#define STM_GPIO_H

#define NO_OF_GPIOS	16


enum cmd_type_id {
	CMD_GPIO = 0x06,
	CMD_PROTO = 0xFC,
	CMD_FW = 0xFD,
	CMD_BOOT = 0xFE
};

enum boot_id {
	BOOT_START_APP = 0x03,
	BOOT_STATE = 0xFD,
	BOOT_VERSION = 0xFE
};

enum state_id {
	WATCHDOG_RESET = 0x1B,
	APP_STARTED = 0xFC,
};

enum ack_id {
	STATUS_ACK = 0x7D,
	STATUS_NACK = 0x7E
};

enum gpio_state {
	GPIO_STATE_HIGH = 0x1E,
	GPIO_STATE_LOW = 0x9F
};

enum gpio_mode {
	GPIO_VALUE_SET_LOW = 0x00,
	GPIO_VALUE_SET_HIGH = 0x01,
	GPIO_VALUE_GET = 0x02,
	GPIO_MODE_SET_OUTPUT = 0x04,
	GPIO_MODE_SET_INPUT = 0x05
};

enum fw_id {
	FW_VERSION = 0x01
};

#endif // R2EC_IO_H