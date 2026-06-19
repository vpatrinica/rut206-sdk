project(STM32_USB_Device_Library)

set(SOURCES
    Core/Inc/usbd_def.h
    Core/Inc/usbd_ctlreq.h
    Core/Src/usbd_ctlreq.c
    Core/Inc/usbd_ioreq.h
    Core/Src/usbd_ioreq.c
    Core/Inc/usbd_core.h
    Core/Src/usbd_core.c
)

set(INCLUDE_DIRS
    Core/Inc/
    config/
)

add_library(STM32_USB_Device_Library_STM32G0B1xK STATIC ${SOURCES})
    target_include_directories(STM32_USB_Device_Library_STM32G0B1xK PUBLIC ${INCLUDE_DIRS})
    target_compile_options(STM32_USB_Device_Library_STM32G0B1xK PRIVATE ${CPUFLAGS_G0} -Wno-unused-parameter -DSTM32G0)
    target_link_libraries(STM32_USB_Device_Library_STM32G0B1xK PRIVATE STM32_HAL_STM32G0B1xK)
