Mobile Application Functional Brief (Android & iOS)

The project aims to develop a cross-platform mobile application (Android and iOS) intended for the simplified monitoring and control of automation relays and lighting dimming modules. The application will allow users to manage consumers individually and to configure essential automation scenarios, being adaptable for residential, commercial, and marine environments.

Application Structure (Main Navigation)

The application will have a Tab Bar with the following four main sections:
- Home
- Configuration
- Scenarios
- Settings

I. Home Section

The main "Home" screen is designed to offer an efficient and informative user experience.

- Quick Access to Scenarios: The buttons of scenarios previously configured in the Configuration section will be displayed, where the "Show in Home" option has been enabled. Users will be able to customize the display order of these buttons via drag-and-drop, for optimal access.
- Immediate Module Status Alert: A prominent banner (red) or a temporary popup will be displayed at the top of the screen to warn the user when a module becomes unavailable (offline). Clicking this section redirects to a System Status page, where there will be a log of error messages.
- Temperature Monitoring and Alerts: The application will allow real-time monitoring of the internal temperature of each module. Users will be able to define temperature thresholds for each module, and the application will generate automatic alerts when these values are exceeded, alerts that will be displayed similarly to point 2.

II. Configuration Section (Detailed Module Management)

This section provides the complete interface for controlling and monitoring each type of module added to the system.

2.1 Adding and Managing Modules

- Simplified Addition: The process of adding modules is quick and efficient. Each module transmits a self-discovery message on the network, a message that can be monitored and used by the application for easy integration.
- Identification: Modules are identified and added to the application based on their IP Address.
- Module Viewing: The main screen of this section (Device List) displays all added modules. Each module is accompanied by a quick visual indicator (a green dot for Online or a red dot for Offline) showing its connectivity status.

Hybrid Mechanism for the Communication Protocol:
- Local Control: Within the local network (LAN), module control will be performed through APIs or direct TCP/IP commands.
- Remote Control: For access outside the local network, the MQTT protocol will be used.

2.2 Detailed Control Interface (Channels and Outputs)

This section represents the operational center of the application, offering individual control over each channel and the physical inputs of the modules.

Output (Channel) Management:
- A clear and concise list of all available outputs of a relay will be presented (for example, 8 distinct outputs).
- Each output will benefit from a large, visible button for Direct Command (ON/OFF), allowing instant start/stop of the connected consumer.
- Customization: Users will have the ability to name each output (e.g., "Cabin Light") and to associate a simple, relevant icon with it, for quick and intuitive identification.

Physical Switch Input Control:
- The application will allow configuring the action associated with physical inputs (switches connected directly to modules). These can be set in the following modes:
  - Momentary Mode: The action is executed only while the button is pressed.
  - Toggle Mode: Each press toggles the state (ON/OFF) of an output or a scenario.
  - Associated Mode: The physical input action is linked directly to a specific output or to a predefined scenario.

2.3 Extended Control Types (Dedicated Modules)

The application will provide dedicated control interfaces for the following types of modules, benefiting from real-time status feedback for each action:

- Standard Relay Modules: ON/OFF control interface for switching the state (closed/open) of consumers.
- Blind Motor Control Modules (DC): Directional control interface with dedicated buttons for driving the DC motors of blinds in the "up" and "down" directions. Toggle functionality: on a first press (e.g., "UP"), the motor starts in the respective direction. A second press of the same "UP" button will stop the motor (similar behavior for "DOWN").
- Lighting Dimming Modules (DC): Intensity control (PWM) interface for adjusting light intensity (dimming) on the 4 outputs of 12-24V DC.
- Lighting Dimming Modules (AC): Intensity control (220V) interface for adjusting light intensity (dimming) on the 4 outputs of 220V AC.
- Temperature Module: Temperature monitoring. The application will display the current temperature and all available functions in the module.
  - Note: The advanced thermostat functionalities and complex temperature control (managed by the module's internal server) will not be exposed in the application in this first phase (Level 1).

2.4 Automations and Scenarios (Scenes)

This section defines the system's capabilities to create and manage custom action sequences, intended to simplify control and bring a high degree of intelligence to the use of devices.

- Action-Based Scenarios (Tap-to-Run): Allows users to configure virtual buttons that, with a single press, execute a series of predefined commands.
- Flexible Configuration: An unlimited number of custom scenarios can be created.
- Multiple Actions: A single scenario can simultaneously control one or more outputs, regardless of whether they belong to relay modules (ON/OFF) or dimmer modules (intensity control).
- Precise Brightness Control: For dimmer modules, scenarios allow setting an exact brightness level (e.g., 30%, 50%, etc.), including the values of 0% for off (OFF) and 100% for on (ON).
- Dedicated Manual Control: A special scenario of the "Manual dimming Slider" type can be configured. It controls a single output of a dimmer module and can be displayed directly on the main screen (HOME) for quick access to intensity adjustment.
- Example: A scenario named "Departure" could, with a single press, execute the following actions:
  - Turn OFF (OFF) the "Cabin Light".
  - Turn ON (ON) the "Navigation Lights".

Smart Automations (Based on IF... THEN... rules):
- Allows creating automatic rules that trigger without human intervention, based on specific conditions, such as:
  - Time of Day: Actions executed automatically at a certain time.
  - Device State: An action is triggered when another device changes its state (e.g., if a sensor turns on, a light turns on).

Event Log (History):
- To ensure complete traceability, the system will implement an "Event History" functionality. It will record a detailed log for every ON/OFF type action, and the logs will be kept and accessible for a period of 30 days.

2.5 Organization by Rooms (Zones)

To provide a logical structure and simplify management, the application will allow grouping scenarios by rooms or zones.

- Creating and Managing Rooms: The user will be able to create and name various zones (e.g., Living Room, Bedroom, Deck, Cabin, etc.).
- Assigning Scenarios: In the process of creating/editing a scenario, it can be assigned to a specific room. * Display on Home: Rooms will be displayed on the main screen for quick access to the corresponding scenario groups.

III. Settings Section

This section centralizes user account management, application settings, and notifications. Creating an account is mandatory to use the application, being a fundamental element that ensures data integrity, configuration backup, and a continuous user experience (if the transfer to another phone is made).

3.1 Account Management and Cloud Synchronization

Each user must create an account to access the application's functionalities. This account serves as a central pillar for the safety and portability of data.

- Mandatory Account Creation/Authentication: On first launch, the application will request the creation of an account based on email and password. Authentication is required to access personal configuration.
- Automatic Backup and Restore: The user account ensures the automatic (backup) and secure saving to the cloud of all configurations: added modules, custom names, created scenarios, and settings.
- Multi-Device Synchronization: Thanks to the account, users can change their phone or install the application on a new device without any reconfiguration effort. After authentication, the entire configuration is downloaded and restored instantly, ensuring a perfect transition and eliminating the risk of data loss.
- Password Recovery: A standard password reset functionality via email is implemented.
- (Note: In the current stage, the user account is used for backing up the application configuration. We do not yet offer a cloud portal where equipment can be administered directly, a functionality planned for a future development stage.)

3.2 Push Notifications

The application will use the account to send personalized alerts in real time, informing the user about critical events even when the application is closed.

- Status Alerts: Push notifications will be sent to the phone for important events.
- Examples of Notifications:
  - A device has disconnected or has come back online.
  - A certain output has remained on for a long period of time.

IV. General and Technical Requirements

This section defines the design, architecture, and localization requirements that will guide the development process, ensuring a solid foundation for the quality and future evolution of the application.

4.1 Design and User Interface (UI/UX)

Although the application addresses the general public, mainly for residential and small commercial spaces, the interface will respect principles of clarity and accessibility.

- Minimalist Design: A clean design will be adopted, with a color palette focused on high contrast (e.g., black and white), to ensure excellent readability in any lighting conditions.
- Control Elements: Buttons and interactive elements will be large and clearly delineated, facilitating fast and error-free usage.

4.2 Architecture and Scalability (Multi-Location)

The application will be built on a flexible architecture, ready for future extensions.

- Multi-Location Support (Architectural): The basic structure of the application and of the user account will be designed to support the management of multiple locations (e.g., Home, Office, Vacation house) under the same account.
- Initial Implementation (Single-Location): In the first version of the application, the functionality will be limited to managing a single location.

4.3 Localization and Language Support

The application will be launched on an international market, requiring technical preparation to accommodate various languages.

- Languages at Launch: The initial version of the application will offer full support for the Romanian and English languages.
- Architecture Ready for Translation: All interface texts in the application (strings) will be implemented in a format that allows for easy and efficient translation in the future (similar to the POT files system on the web).
- Expansion Plan: Subsequently, support for other European languages, such as Spanish, French, and German, is planned.

V. Project Stages and Deliverables

To ensure transparency, control, and an efficient workflow, the project will be structured in the following distinct stages. Each stage will end with clear deliverables, whose validation will allow moving to the next phase.

Stage 1: Planning and Kick-off
- Description: Setting the project strategy, detailed definition of objectives, aligning teams and configuring communication and project management channels.
- Deliverable: Project planning document, with an estimated schedule. The stage we are currently in.

Stage 2: UI/UX Design and Prototyping
- Description: Creating the visual architecture and user experience. This phase is fundamental and precedes development. All application screens and an interactive prototype will be created to collect feedback.
- Deliverable: Complete interactive prototype (e.g., in Figma), validated and approved.

Stage 3: Hardware Delivery and Technical Documentation
- Description: In this essential stage, the client will provide one physical product of each type of module (standard relay, dimmer, blind control, etc.), together with their complete technical documentation (API, communication protocols). These are indispensable to enable the direct development and testing of the hardware-software integration.
- Deliverable: Physical modules and documentation received; confirmation of initial communication between the test environment and the modules.

Stage 4: Technical Development (Implementation)
- Description: Based on the approved design and hardware documentation, the technical implementation of the application will begin. This will include architecture setup, the development of each section (Home, Configuration, Scenarios, Settings), integration with cloud services, and the implementation of communication protocols. The client will periodically receive intermediate versions (builds) to track progress.
- Deliverable: A fully functional version of the application (Alpha/Beta), with all features implemented.

Stage 5: Final Testing (QA) and Optimization
- Description: Rigorous testing of the application on multiple devices (iOS and Android) to identify and fix any error (bug). Functionality, performance, security, and user experience will be verified.
- Deliverable: A stable version of the application, ready for launch.

Stage 6: Launch and Publication in Stores
- Description: Preparing the necessary materials (descriptions, screenshots) and publishing the application in the official stores, Google Play Store and Apple App Store. Includes managing the review process of each platform.
- Deliverable: Application published and available for download.

Stage 7: Post-Launch Support and Maintenance
- Description: After launch, a technical support period (warranty) will be offered to fix any critical issues that were not discovered during the testing phase. A long-term maintenance plan can also be discussed.
- Deliverable: Application monitored and stable in production.
