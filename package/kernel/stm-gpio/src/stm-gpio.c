#include <linux/module.h>
#include <linux/gpio/driver.h>
#include <linux/interrupt.h>
#include <linux/i2c.h>
#include <linux/delay.h>

#include "io.h"

static const struct i2c_device_id r2ec_id[] = {
	{ "stm-gpio", NO_OF_GPIOS },
	{ }
};
MODULE_DEVICE_TABLE(i2c, r2ec_id);

static const struct of_device_id r2ec_of_table[] = {
	{ .compatible = "tlt,stm-gpio" },
	{ }
};
MODULE_DEVICE_TABLE(of, r2ec_of_table);

struct r2ec {
	struct gpio_chip chip;
	struct i2c_client *client;
	struct mutex i2c_lock;
	int ic_ready;
};

struct r2ec_platform_data {
	unsigned gpio_base;

	int (*setup)(struct i2c_client *client, int gpio, unsigned ngpio,
		     void *context);

	int (*teardown)(struct i2c_client *client, int gpio, unsigned ngpio,
			void *context);

	void *context;
};

struct i2c_frame {
	uint8_t length;
	uint8_t command;
	uint8_t data[8];
} __attribute__((packed));

static int stm32_write(struct i2c_client *client, uint8_t cmd,
		       uint8_t *data, size_t len)
{
	struct i2c_frame *req;
	uint8_t tmp[sizeof(struct i2c_frame)];
	int err;

	if (!client) {
		printk(KERN_ERR "R2EC I2C client is not ready!\n");
		return -ENXIO;
	}

	req = (struct i2c_frame *)tmp;
	req->length  = len;
	req->command = cmd;

	memcpy(req->data, data, len);

	if ((err = i2c_master_send(client, tmp, len + 2)) < 0) {
		return err;
	}

	return 0;
}

// attempt to read i2c data
static int stm32_read(struct i2c_client *client, uint8_t *data, size_t len)
{
	int err;
	unsigned cnt = 0;

	if (!client) {
		printk(KERN_ERR "R2EC I2C client is not ready!\n");
		return -ENXIO;
	}

retry:
	if ((err = i2c_master_recv(client, data, len)) < 0) {
		if (err == -ETIMEDOUT && cnt < 5) {
			cnt++;
			msleep(10);
			goto retry;
		}
		return err;
	}

	return 0;
}

static int stm32_prepare(struct r2ec *gpio, struct i2c_client *client)
{
	struct i2c_frame rsp;
	uint8_t data[1], recv[1];
	int ret;

	memset(&rsp, 0, sizeof(rsp));

	data[0] = BOOT_STATE;
	if ((ret = stm32_write(client, CMD_BOOT, data, 1))) {
		dev_err(&client->dev,
			"stm32_prepare: boot state write failed (%d)\n", ret);
		return ret;
	}

	if ((ret = stm32_read(client, recv, 1))) {
		dev_err(&client->dev,
			"stm32_prepare: boot state read failed (%d)\n", ret);
		return ret;
	}

	gpio->ic_ready = 0;

	switch (recv[0]) {
	case APP_STARTED:
		// device is ready, no need to ignore gpio_write status value
		// note: on no_image_found, user-space flasher will reflash
		//  firmware and device will be rebooted
		gpio->ic_ready = 1;
		return 0;
	default:
		dev_err(&client->dev, "Device did not responded with correct "
				      "state! Actual response was 0x%02X. "
				      "Unable to get device state!\n", recv[0]);
		break;
	}

	return 0;
}

static int stm32_gpio_write(struct r2ec *gpio, int pin, int val)
{
	struct i2c_frame *req;
	uint8_t len = 2, retry = 10;
	uint8_t tmp[sizeof(struct i2c_frame)];
	int err;

	if (!gpio->client) {
		printk(KERN_ERR "R2EC I2C client is not ready!\n");
		return -ENXIO;
	}

	req = (struct i2c_frame *)tmp;
	req->length  = len;
	req->command = CMD_GPIO;
	req->data[0] = pin;
	req->data[1] = val;

	while ((err = i2c_master_send(gpio->client, tmp, len + 2)) < 0) {
		if(retry--)continue;
		return err;
	}

	return 0;
}

static int stm32_gpio_read(struct r2ec *gpio, int pin, int val)
{
	struct i2c_frame *req;
	uint8_t len = 2, retry = 10;
	uint8_t tmp[sizeof(struct i2c_frame)];
	uint8_t recv[1];
	int err;

	if (!gpio->client) {
		return -ENXIO;
	}

	req = (struct i2c_frame *)tmp;
	req->length  = len;
	req->command = CMD_GPIO;
	req->data[0] = pin;
	req->data[1] = val;

	while((err = i2c_master_send(gpio->client, tmp, len + 2)) < 0) {
		if(retry--)continue;
		return err;
	}

	retry = 10;
	while ((err = i2c_master_recv(gpio->client, recv, 1)) < 0) {
		if(retry--)continue;
		return err;
	}

	switch (recv[0]) {
	case GPIO_STATE_HIGH:
		return 1;
	case GPIO_STATE_LOW:
		return 0;
	}

	return -EIO;
}

static int r2ec_get(struct gpio_chip *chip, unsigned offset)
{
	struct r2ec *gpio = gpiochip_get_data(chip);
	int value;

	mutex_lock(&gpio->i2c_lock);
	value = stm32_gpio_read(gpio, offset, GPIO_VALUE_GET);
	mutex_unlock(&gpio->i2c_lock);

	return value;
}

static void r2ec_set(struct gpio_chip *chip, unsigned offset, int value)
{
	struct r2ec *gpio = gpiochip_get_data(chip);
	int val = value ? GPIO_VALUE_SET_HIGH : GPIO_VALUE_SET_LOW;

	mutex_lock(&gpio->i2c_lock);
	stm32_gpio_write(gpio, offset, val);
	mutex_unlock(&gpio->i2c_lock);
}

static int r2ec_input(struct gpio_chip *chip, unsigned offset)
{
	struct r2ec *gpio = gpiochip_get_data(chip);
	int status;

	mutex_lock(&gpio->i2c_lock);
	status = stm32_gpio_write(gpio, offset, GPIO_MODE_SET_INPUT);
	mutex_unlock(&gpio->i2c_lock);

	return status;
}

static int r2ec_output(struct gpio_chip *chip, unsigned offset, int value)
{
	struct r2ec *gpio = gpiochip_get_data(chip);
	int status;

	mutex_lock(&gpio->i2c_lock);
	status = stm32_gpio_write(gpio, offset, GPIO_MODE_SET_OUTPUT);
	mutex_unlock(&gpio->i2c_lock);

	r2ec_set(chip, offset, value);

	return status;
}

static int chip_label_match(struct gpio_chip *chip, void *data)
{
	return !strcmp(chip->label, data);
}

static int get_stm32_version(struct device *dev, uint8_t type, char *buffer)
{
	struct gpio_chip *chip;
	struct r2ec *gpio;
	uint8_t data[64];
	int ret;

	chip = gpiochip_find("stm-gpio", chip_label_match);
	if (!chip) {
		printk(KERN_ERR "Unable to find R2EC gpio chip!\n");
		return -ENXIO;
	}

	gpio = gpiochip_get_data(chip);

	if (!gpio->client) {
		printk(KERN_ERR "R2EC I2C client is not ready!\n");
		return -ENXIO;
	}

	data[0] =  FW_VERSION;

	mutex_lock(&gpio->i2c_lock);

	if ((ret = stm32_write(gpio->client, type, data, 1))) {
		printk("%s: firmware version write failed (%d)\n",
			__func__, ret);
		goto done;
	}

	memset(data, 0, sizeof(data));

	if ((ret = stm32_read(gpio->client, data, 1))) {
		printk("%s: firmware version read failed (%d)\n",
			__func__, ret);
		goto done;
	}

	if ((ret = stm32_read(gpio->client, data, data[0]))) {
		printk("%s: firmware version read failed (%d)\n",
			__func__, ret);
		goto done;
	}

	strncpy(buffer, &data[1], sizeof(data) - 1);

done:
	mutex_unlock(&gpio->i2c_lock);
	return strlen(buffer);
}

static ssize_t fw_version_show(struct device *dev,
				struct device_attribute *attr, char *buffer)
{
	buffer[0] = 0;
	return get_stm32_version(dev, CMD_FW, buffer);
}


static struct device_attribute g_r2ec_kobj_attr[] = {
	__ATTR_RO(fw_version),
};

static struct attribute *g_r2ec_attrs[] = {
	&g_r2ec_kobj_attr[0].attr,
	NULL,
};

static struct attribute_group g_r2ec_attr_group = { .attrs = g_r2ec_attrs };
static struct kobject *g_r2ec_kobj;

static int r2ec_probe(struct i2c_client *client, const struct i2c_device_id *id)
{
	struct r2ec_platform_data *pdata = dev_get_platdata(&client->dev);
	struct r2ec *gpio;
	int status, i;

	gpio = devm_kzalloc(&client->dev, sizeof(*gpio), GFP_KERNEL);
	if (!gpio) {
		return -ENOMEM;
	}

	for (i = 0; i < 10; i++) {
		if (!(status = stm32_prepare(gpio, client))) {
			break;
		}

		dev_err(&client->dev,
			"Unable to initialize device, retrying...\n");

		// give some time for next interation...
		msleep(500);
	}

	if (status) {
		dev_err(&client->dev, "Unable to initialize device!\n");
		devm_kfree(&client->dev, gpio);
		return status;
	}

	mutex_init(&gpio->i2c_lock);

	lockdep_set_subclass(&gpio->i2c_lock,
			     i2c_adapter_depth(client->adapter));

	gpio->chip.base = pdata ? pdata->gpio_base : -1;
	gpio->chip.can_sleep = true;
	gpio->chip.parent = &client->dev;
	gpio->chip.owner = THIS_MODULE;
	gpio->chip.get = r2ec_get;
	gpio->chip.set = r2ec_set;
	gpio->chip.direction_input = r2ec_input;
	gpio->chip.direction_output = r2ec_output;
	gpio->chip.ngpio = id->driver_data;
	gpio->chip.label = client->name;
	gpio->client = client;

	i2c_set_clientdata(client, gpio);

	status = devm_gpiochip_add_data(&client->dev, &gpio->chip, gpio);
	if (status < 0) {
		goto fail;
	}

	if (pdata && pdata->setup) {
		status = pdata->setup(client, gpio->chip.base, gpio->chip.ngpio,
				      pdata->context);

		if (status < 0) {
			dev_warn(&client->dev, "setup --> %d\n", status);
		}
	}

	dev_info(&client->dev, "probed\n");
	return 0;

fail:
	devm_kfree(&client->dev, gpio);
	dev_dbg(&client->dev, "probe error %d for %s\n", status, client->name);
	return status;
}

static int r2ec_remove(struct i2c_client *client)
{
	struct r2ec_platform_data *pdata = dev_get_platdata(&client->dev);
	struct r2ec *gpio = i2c_get_clientdata(client);
	int status = 0;

	if (!(pdata && pdata->teardown)) {
		return 0;
	}

	status = pdata->teardown(client, gpio->chip.base, gpio->chip.ngpio,
				 pdata->context);

	if (status < 0) {
		dev_err(&client->dev, "%s --> %d\n", "teardown", status);
	}

	return 0;
}

static struct i2c_driver r2ec_driver = {
	.driver = {
		.name	= "stm-gpio",
		.of_match_table = of_match_ptr(r2ec_of_table),
	},
	.probe	= r2ec_probe,
	.remove	= r2ec_remove,
	.id_table = r2ec_id,
};

static int __init r2ec_init(void)
{
	int ret;

	ret = i2c_add_driver(&r2ec_driver);
	if (ret) {
		printk(KERN_ERR "Unable to initialize `stm-gpio` driver!\n");
		return ret;
	}

	g_r2ec_kobj = kobject_create_and_add("stm-gpio", NULL);
	if (!g_r2ec_kobj) {
		i2c_del_driver(&r2ec_driver);
		printk(KERN_ERR "Unable to create `stm-gpio` kobject!\n");
		return -ENOMEM;
	}

	if (sysfs_create_group(g_r2ec_kobj, &g_r2ec_attr_group)) {
		kobject_put(g_r2ec_kobj);
		i2c_del_driver(&r2ec_driver);
		printk(KERN_ERR "Unable to create `stm-gpio` sysfs group!\n");
		return -ENOMEM;
	}

	return 0;
}

static void __exit r2ec_exit(void)
{
	kobject_put(g_r2ec_kobj);
	i2c_del_driver(&r2ec_driver);
}

module_init(r2ec_init);
module_exit(r2ec_exit);

MODULE_AUTHOR("Alvydas Sidlauskas <alvydas.sidlauskas@teltonika.lt>");
MODULE_DESCRIPTION("STM32 I2C GPIO Expander driver");
MODULE_LICENSE("GPL v2");
