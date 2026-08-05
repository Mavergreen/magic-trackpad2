//
//  VoodooInput.сpp
//  VoodooInput
//
//  Copyright © 2019 Kishor Prins. All rights reserved.
// Copyright (c) 2020 Leonard Kleinhans <leo-labs>
//

#include "VoodooInput.hpp"
#include "VoodooInputIDs.hpp"
#include "VoodooInputMultitouch/VoodooInputMessages.h"
#include "VoodooInputSimulator/VoodooInputActuatorDevice.hpp"
#include "VoodooInputSimulator/VoodooInputSimulatorDevice.hpp"
#include "Trackpoint/TrackpointDevice.hpp"
#include "VoodooInputTerminal.hpp"
#include <libkern/c++/OSString.h>

#include "libkern/version.h"

#define super IOService
OSDefineMetaClassAndStructors(VoodooInput, IOService);

bool VoodooInput::start(IOService *provider) {
    if (!super::start(provider)) {
        IOLog("Kishor VoodooInput could not super::start!\n");
        return false;
    }
    
    parentProvider = provider;

    if (!updateProperties()) {
        IOLog("VoodooInput could not get provider properties!\n");
        return false;
    }

    // On pre-El Capitan macOS the multitouch stack won't bind a virtual IOHIDDevice, so the simulator can't
    // dispatch. If the provider advertises a concrete VoodooInputTerminal (by class name), drive that instead
    // and skip the simulator. If none is advertised (or it fails to start), fall through to the simulator so
    // every existing provider's behavior is unchanged.
    if (version_major < kVoodooInputVersionElCapitan) {
        OSString* cls = OSDynamicCast(OSString, provider->getProperty("VoodooInputLegacyTerminalClass"));
        if (cls) {
            OSObject* o = OSMetaClass::allocClassWithName(cls->getCStringNoCopy());
            legacyTerminal = OSDynamicCast(VoodooInputTerminal, o);
            if (o && !legacyTerminal) {   // advertised class wasn't a VoodooInputTerminal
                IOLog("VoodooInput: advertised VoodooInputLegacyTerminalClass '%s' is not a VoodooInputTerminal\n", cls->getCStringNoCopy());
                o->release();
            }
            if (legacyTerminal && !legacyTerminal->start(this, provider)) {
                IOLog("VoodooInput: legacy terminal '%s' failed to start\n", cls->getCStringNoCopy());
                legacyTerminal->release(); legacyTerminal = 0;
            }
        }
        if (legacyTerminal) goto terminals_ready;   // provider supplied a working terminal; skip the simulator
    }

    // Allocate the simulator and actuator devices
    simulator = OSTypeAlloc(VoodooInputSimulatorDevice);
    actuator = OSTypeAlloc(VoodooInputActuatorDevice);
    trackpoint = OSTypeAlloc(TrackpointDevice);
    
    if (!simulator || !actuator || !trackpoint) {
        IOLog("VoodooInput could not alloc simulator, actuator or trackpoint!\n");
        OSSafeReleaseNULL(simulator);
        OSSafeReleaseNULL(actuator);
        OSSafeReleaseNULL(trackpoint);
        return false;
    }
    
    // Initialize simulator device
    if (!simulator->init(NULL) || !simulator->attach(this)) {
        IOLog("VoodooInput could not attach simulator!\n");
        goto exit;
    }
    else if (!simulator->start(this)) {
        IOLog("VoodooInput could not start simulator!\n");
        simulator->detach(this);
        goto exit;
    }
    
    // Initialize actuator device
    if (!actuator->init(NULL) || !actuator->attach(this)) {
        IOLog("VoodooInput could not init or attach actuator!\n");
        goto exit;
    }
    else if (!actuator->start(this)) {
        IOLog("VoodooInput could not start actuator!\n");
        actuator->detach(this);
        goto exit;
    }
    
    // Initialize trackpoint device
    if (!trackpoint->init(NULL) || !trackpoint->attach(this)) {
        IOLog("VoodooInput could not init or attach trackpoint!\n");
        goto exit;
    }
    else if (!trackpoint->start(this)) {
        IOLog("VoodooInput could not start trackpoint!\n");
        trackpoint->detach(this);
        goto exit;
    }
    
terminals_ready:
    setProperty(VOODOO_INPUT_IDENTIFIER, kOSBooleanTrue);
    
    if (!parentProvider->open(this)) {
        IOLog("VoodooInput could not open!\n");
        return false;
    };
    
    return true;

exit:
    return false;
}

bool VoodooInput::willTerminate(IOService* provider, IOOptionBits options) {
    if (parentProvider->isOpen(this)) {
        parentProvider->close(this);
    }

    return super::willTerminate(provider, options);
}

void VoodooInput::stop(IOService *provider) {
    if (legacyTerminal) { legacyTerminal->stop(this); OSSafeReleaseNULL(legacyTerminal); }

    if (simulator) {
        simulator->stop(this);
        simulator->detach(this);
        OSSafeReleaseNULL(simulator);
    }
    
    if (actuator) {
        actuator->stop(this);
        actuator->detach(this);
        OSSafeReleaseNULL(actuator);
    }
    
    if (trackpoint) {
        trackpoint->stop(this);
        trackpoint->detach(this);
        OSSafeReleaseNULL(trackpoint);
    }
    
    super::stop(provider);
}

bool VoodooInput::updateProperties() {
    OSNumber* transformNumber = OSDynamicCast(OSNumber, getProperty(VOODOO_INPUT_TRANSFORM_KEY, gIOServicePlane));
    OSNumber* logicalMaxXNumber = OSDynamicCast(OSNumber, getProperty(VOODOO_INPUT_LOGICAL_MAX_X_KEY, gIOServicePlane));
    OSNumber* logicalMaxYNumber = OSDynamicCast(OSNumber, getProperty(VOODOO_INPUT_LOGICAL_MAX_Y_KEY, gIOServicePlane));
    OSNumber* physicalMaxXNumber = OSDynamicCast(OSNumber, getProperty(VOODOO_INPUT_PHYSICAL_MAX_X_KEY, gIOServicePlane));
    OSNumber* physicalMaxYNumber = OSDynamicCast(OSNumber, getProperty(VOODOO_INPUT_PHYSICAL_MAX_Y_KEY, gIOServicePlane));

    if (transformNumber == nullptr || logicalMaxXNumber == nullptr || logicalMaxYNumber == nullptr ||
        physicalMaxXNumber == nullptr || physicalMaxYNumber == nullptr) {
        return false;
    }

    transformKey = transformNumber->unsigned8BitValue();
    logicalMaxX = logicalMaxXNumber->unsigned32BitValue();
    logicalMaxY = logicalMaxYNumber->unsigned32BitValue();
    physicalMaxX = physicalMaxXNumber->unsigned32BitValue();
    physicalMaxY = physicalMaxYNumber->unsigned32BitValue();

    return true;
}

UInt8 VoodooInput::getTransformKey() {
    return transformKey;
}

UInt32 VoodooInput::getPhysicalMaxX() {
    return physicalMaxX;
}

UInt32 VoodooInput::getPhysicalMaxY() {
    return physicalMaxY;
}

UInt32 VoodooInput::getLogicalMaxX() {
    return logicalMaxX;
}

UInt32 VoodooInput::getLogicalMaxY() {
    return logicalMaxY;
}

IOReturn VoodooInput::message(UInt32 type, IOService *provider, void *argument) {
    switch (type) {
        case kIOMessageVoodooInputMessage:
            if (provider == parentProvider && argument && legacyTerminal) {
                legacyTerminal->handleEvent((const VoodooInputEvent*)argument);
                break;
            }
            if (provider == parentProvider && argument && simulator)
                simulator->constructReport(*(VoodooInputEvent*)argument);
            break;
            
        case kIOMessageVoodooInputUpdateDimensionsMessage:
            if (provider == parentProvider && argument) {
                const VoodooInputDimensions& dimensions = *(VoodooInputDimensions*)argument;
                logicalMaxX = dimensions.max_x - dimensions.min_x;
                logicalMaxY = dimensions.max_y - dimensions.min_y;
                if (legacyTerminal) legacyTerminal->updateDimensions(logicalMaxX, logicalMaxY);
            }
            break;
            
        case kIOMessageVoodooInputUpdatePropertiesNotification:
            updateProperties();
            break;
            
        case kIOMessageVoodooTrackpointRelativePointer: {
            if (trackpoint) {
                const RelativePointerEvent& event = *(RelativePointerEvent*)argument;
                trackpoint->updateRelativePointer(event.dx, event.dy, event.buttons, event.timestamp);
            }
            break;
        }
        case kIOMessageVoodooTrackpointScrollWheel: {
            if (trackpoint) {
                const ScrollWheelEvent& event = *(ScrollWheelEvent*)argument;
                trackpoint->updateScrollwheel(event.deltaAxis1, event.deltaAxis2, event.deltaAxis3, event.timestamp);
            }
            break;
        }
        case kIOMessageVoodooTrackpointMessage:
            if (trackpoint) {
                trackpoint->reportPacket(*(TrackpointReport *)argument);
            }
            break;
        case kIOMessageVoodooTrackpointUpdatePropertiesNotification:
            if (trackpoint) {
                trackpoint->updateTrackpointProperties();
            }
            break;
    }

    return super::message(type, provider, argument);
}

int VoodooInputGetProductId() {
    if (version_major >= kVoodooInputVersionMonterey) {
        return kVoodooInputProductMacbookAir10_1;
    }
    
    return kVoodooInputProductMacbook8_1;
}
