# Contactly
# Never walk into a meeting unprepared.
Contactly is a personal relationship management app that prepares you before meetings, tracks your interactions, and reminds you to follow up.
Built for people who care about their network.
🚀 What It Does
Contactly connects your calendar and contacts to give you context before every meeting.
Core Features
📅 Calendar integration (Apple & Google)
👤 Smart contact matching
🧠 Prep view before meetings
📝 Interaction logging
🔁 Smart follow-ups
🌅 Daily morning briefing
📊 Relationship strength indicator
🔔 Meeting reminders
🧠 How It Works
Sync your calendar.
Sync your contacts.
Before each meeting, Contactly:
Identifies who you're meeting
Shows past notes
Displays last interaction
Suggests follow-ups
After meetings, you can log:
What was discussed
Next action
Follow-up date
Contactly keeps your relationships warm and intentional.
🏗 Architecture
Built with:
SwiftUI
EventKit (Apple Calendar)
Google Calendar API
Local persistence (JSON-based repositories)
MVVM-style architecture
Main components:
CalendarService
InteractionRepository
PrepView
MorningBriefingView
ContactView
Unified TodayView
📱 Screens
Onboarding
Today (meetings + follow-ups)
Contacts
Contact detail (relationship health)
Prep view
Settings
🔒 Privacy
All data is stored locally.
No external analytics.
Calendar and contacts access is explicit and user-controlled.
Permissions can be revoked anytime in Settings.
🎯 Vision
Most people manage tasks.
Few manage relationships.
Contactly exists to help you remember what matters about people.
