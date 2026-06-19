#ifndef INC_I2C_SLAVE_H_
#define INC_I2C_SLAVE_H_

struct i2c_frame {
	uint8_t length;
	uint8_t command;
	uint8_t data[8];
} __attribute__((packed));

void i2c_slave_init(I2C_HandleTypeDef *hi2c);
void i2c_slave_check_timeout(I2C_HandleTypeDef *hi2c);

#endif /* INC_I2C_SLAVE_H_ */