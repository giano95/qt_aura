cmake_minimum_required(VERSION 3.16)

project(qt_aura VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick QuickControls2)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appqt_aura
    main.cpp
)

# QML singletons: design tokens, session state, prototype data
set(AURA_QML_SINGLETONS
    qml/theme/Theme.qml
    qml/services/Session.qml
    qml/services/MockData.qml
    qml/services/ProgramStore.qml
    qml/services/ClientStore.qml
    qml/services/CalendarStore.qml
    qml/services/CoachStore.qml
)
set_source_files_properties(${AURA_QML_SINGLETONS}
    PROPERTIES QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(appqt_aura
    URI qt_aura
    QML_FILES
        Main.qml
        ${AURA_QML_SINGLETONS}

        # Reusable components
        qml/components/AppShell.qml
        qml/components/AuraButton.qml
        qml/components/AuraDialog.qml
        qml/components/AuraMenu.qml
        qml/components/AuraTextArea.qml
        qml/components/AuraTextField.qml
        qml/components/AuthPage.qml
        qml/components/Avatar.qml
        qml/components/BrandMark.qml
        qml/components/BrandPanel.qml
        qml/components/Card.qml
        qml/components/CheckRow.qml
        qml/components/Chip.qml
        qml/components/ConfirmDialog.qml
        qml/components/DatePicker.qml
        qml/components/EmptyState.qml
        qml/components/FilterChip.qml
        qml/components/GreetingHeader.qml
        qml/components/IconButton.qml
        qml/components/NavButton.qml
        qml/components/Notice.qml
        qml/components/PageHeader.qml
        qml/components/PlaceholderPage.qml
        qml/components/ProgressTrack.qml
        qml/components/RoleCard.qml
        qml/components/AuraSearchField.qml
        qml/components/AuraSwitch.qml
        qml/components/SegmentedTabs.qml
        qml/components/StatCard.qml
        qml/components/TimeStepper.qml
        qml/components/Toast.qml

        # Screens
        qml/screens/auth/AuthFlow.qml
        qml/screens/auth/WelcomeScreen.qml
        qml/screens/auth/LoginScreen.qml
        qml/screens/auth/SignupScreen.qml
        qml/screens/coach/CoachHome.qml
        qml/screens/coach/CoachDashboard.qml
        qml/screens/coach/calendar/BookingRequestsDialog.qml
        qml/screens/coach/calendar/CalendarPage.qml
        qml/screens/coach/calendar/WeekCalendar.qml
        qml/screens/coach/calendar/WorkingHoursEditor.qml
        qml/screens/coach/calendar/WorkingHoursDialog.qml
        qml/screens/coach/clients/AssignProgramDialog.qml
        qml/screens/coach/clients/ClientDetail.qml
        qml/screens/coach/clients/ClientRow.qml
        qml/screens/coach/clients/ClientsHome.qml
        qml/screens/coach/clients/ClientsSection.qml
        qml/screens/coach/clients/ClientRequestsDialog.qml
        qml/screens/coach/clients/ProfileVisibilityDialog.qml
        qml/screens/coach/clients/InviteClientDialog.qml
        qml/screens/coach/programs/DayCard.qml
        qml/screens/coach/programs/ExerciseCard.qml
        qml/screens/coach/programs/ExerciseFormDialog.qml
        qml/screens/coach/programs/ExerciseLibrary.qml
        qml/screens/coach/programs/ExercisePickerDialog.qml
        qml/screens/coach/programs/ExercisesPage.qml
        qml/screens/coach/programs/ProgramCard.qml
        qml/screens/coach/programs/ProgramEditor.qml
        qml/screens/coach/programs/ProgramExerciseRow.qml
        qml/screens/coach/programs/ProgramList.qml
        qml/screens/coach/programs/ProgramsHome.qml
        qml/screens/coach/programs/ProgramsSection.qml
        qml/screens/client/ClientHome.qml
        qml/screens/client/ClientDashboard.qml
        qml/screens/client/calendar/ClientBookingCalendar.qml
        qml/screens/client/calendar/BookSessionDialog.qml
        qml/screens/client/calendar/ClientCalendarPage.qml
        qml/screens/client/calendar/ClientSessionCard.qml
        qml/screens/client/coach/CoachCard.qml
        qml/screens/client/coach/CoachDirectory.qml
        qml/screens/client/coach/CoachProfile.qml
        qml/screens/client/coach/CoachProfileDialog.qml
        qml/screens/client/coach/MyCoachPage.qml
        qml/screens/client/coach/RequestCoachDialog.qml
        qml/screens/client/program/ClientDayCard.qml
        qml/screens/client/program/ClientExerciseRow.qml
        qml/screens/client/program/ClientProgramPage.qml
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appqt_aura PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appqt_aura
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appqt_aura
    PRIVATE Qt6::Quick Qt6::QuickControls2
)

include(GNUInstallDirs)
install(TARGETS appqt_aura
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
