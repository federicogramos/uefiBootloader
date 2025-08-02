;;==============================================================================
;; EFI constants, services, protocols, etc | @file /asm/include/efi.inc
;;==============================================================================


;; EFI_STATUS Success Codes (High Bit Clear)
EFI_SUCCESS					equ 0

;; EFI_STATUS Error Codes (High Bit Set)
EFI_LOAD_ERROR				equ 1
EFI_INVALID_PARAMETER		equ 2
EFI_UNSUPPORTED				equ 3
EFI_BAD_BUFFER_SIZE			equ 4
EFI_BUFFER_TOO_SMALL		equ 5
EFI_NOT_READY				equ 6
EFI_DEVICE_ERROR			equ 7
EFI_WRITE_PROTECTED			equ 8
EFI_OUT_OF_RESOURCES		equ 9
EFI_VOLUME_CORRUPTED		equ 10
EFI_VOLUME_FULL				equ 11
EFI_NO_MEDIA				equ 12
EFI_MEDIA_CHANGED			equ 13
EFI_NOT_FOUND				equ 14
;;EFI_ACCESS_DENIED 15 Access was denied.
;;EFI_NO_RESPONSE 16 The server was not found or did not respond to the request.
;;EFI_NO_MAPPING 17 A mapping to a device does not exist.
;;EFI_TIMEOUT 18 The timeout time expired.
;;EFI_NOT_STARTED 19 The protocol has not been started.
;;EFI_ALREADY_STARTED 20 The protocol has already been started.
;;EFI_ABORTED 21 The operation was aborted.
;;EFI_ICMP_ERROR 22 An ICMP error occurred during the network operation.
;;EFI_TFTP_ERROR 23 A TFTP error occurred during the network operation.
;;EFI_PROTOCOL_ERROR 24 A protocol error occurred during the network operation.
;;EFI_INCOMPATIBLE_VERSION 25 The function encountered an internal version that was
;;incompatible with a version requested by the caller.
;;EFI_SECURITY_VIOLATION 26 The function was not performed due to a security violation.
;;EFI_CRC_ERROR 27 A CRC error was detected.

;; EFI system table.
;; typedef struct {
;;		EFI_TABLE_HEADER				Hdr;					(8 * 3 bytes)
;;		CHAR16							*FirmwareVendor;		(8 bytes)
;;		UINT32							FirmwareRevision;		(8 bytes)
;;		EFI_HANDLE						ConsoleInHandle;		(8 bytes)
;;		SIMPLE_INPUT_INTERFACE			*ConIn;					(8 bytes)
;;		EFI_HANDLE						ConsoleOutHandle;		(8 bytes)
;;		SIMPLE_TEXT_OUTPUT_INTERFACE	*ConOut;				(8 bytes)
;;		EFI_HANDLE						StandardErrorHandle;	(8 bytes)
;;		SIMPLE_TEXT_OUTPUT_INTERFACE	*StdErr;				(8 bytes)
;;		EFI_RUNTIME_SERVICES			*RuntimeServices;		(8 bytes)
;;		EFI_BOOT_SERVICES				*BootServices;			(8 bytes)
;;		UINTN							NumberOfTableEntries;	(8 bytes)
;;		EFI_CONFIGURATION_TABLE			*ConfigurationTable;
;; } EFI_SYSTEM_TABLE;

EFI_SYSTEM_TABLE_FW_VENDOR				equ	24
EFI_SYSTEM_TABLE_CONIN_HANDLE			equ 40
EFI_SYSTEM_TABLE_CONIN					equ 48
EFI_SYSTEM_TABLE_CONOUT					equ 64
EFI_SYSTEM_TABLE_RUNTIMESERVICES		equ 88
EFI_SYSTEM_TABLE_BOOTSERVICES			equ 96
EFI_SYSTEM_TABLE_NUMBEROFENTRIES		equ 104
EFI_SYSTEM_TABLE_CONFIGURATION_TABLE	equ 112

;; typedef struct _EFI_SIMPLE_TEXT_INPUT_PROTOCOL {
;; EFI_INPUT_RESET						Reset;
;; EFI_INPUT_READ_KEY					ReadKeyStroke;
;; EFI_EVENT							WaitForKey;
;; } EFI_SIMPLE_TEXT_INPUT_PROTOCOL;
EFI_INPUT_RESET							equ 0
EFI_INPUT_READ_KEY						equ 8
EFI_EVENT								equ 16

;; typedef struct _EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL {
;; EFI_TEXT_RESET						Reset;
;; EFI_TEXT_STRING						OutputString;
;; EFI_TEXT_TEST_STRING					TestString;
;; EFI_TEXT_QUERY_MODE					QueryMode;
;; EFI_TEXT_SET_MODE					SetMode;
;; EFI_TEXT_SET_ATTRIBUTE				SetAttribute;
;; EFI_TEXT_CLEAR_SCREEN				ClearScreen;
;; EFI_TEXT_SET_CURSOR_POSITION			SetCursorPosition;
;; EFI_TEXT_ENABLE_CURSOR				EnableCursor;
;; SIMPLE_TEXT_OUTPUT_MODE				*Mode;
;; } EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL;
EFI_OUT_RESET							equ 0
EFI_OUT_OUTPUTSTRING					equ 8
EFI_OUT_TEST_STRING						equ 16
EFI_OUT_QUERY_MODE						equ 24
EFI_OUT_SET_MODE						equ 32
EFI_OUT_SET_ATTRIBUTE					equ 40
EFI_OUT_CLEAR_SCREEN					equ 48
EFI_OUT_SET_CURSOR_POSITION				equ 56
EFI_OUT_ENABLE_CURSOR					equ 64
EFI_OUT_MODE							equ 72

EFI_BOOT_SERVICES_GETMEMORYMAP			equ 56
EFI_BOOT_SERVICES_HANDLEPROTOCOL		equ 152
EFI_BOOT_SERVICES_LOCATEHANDLE			equ 176
rEFI_BOOT_SERVICES_LOADIMAGE			equ 200
EFI_BOOT_SERVICES_EXIT					equ 216
EFI_BOOT_SERVICES_EXITBOOTSERVICES		equ 232
EFI_BOOT_SERVICES_STALL					equ 248
EFI_BOOT_SERVICES_SETWATCHDOGTIMER		equ 256
EFI_LOCATE_HANDLE_BUFFER				equ	312
EFI_BOOT_SERVICES_LOCATEPROTOCOL		equ 320

EFI_GRAPHICS_OUTPUT_PROTOCOL_QUERY_MODE	equ 0
EFI_GRAPHICS_OUTPUT_PROTOCOL_SET_MODE	equ 8
EFI_GRAPHICS_OUTPUT_PROTOCOL_BLT		equ 16
EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE		equ 24

EFI_RUNTIME_SERVICES_RESETSYSTEM		equ 104


DATA_HI_START_LOAD	equ 0x406400	;; Image load + offsetPayload + tsl.sys off
									;; set = 0x400000 + 0x4000 + 0x2400.