-- Sample data for testing the Emailinator storage schema
-- Users
INSERT INTO users (username, api_key) VALUES ('alice', 'secret');
INSERT INTO users (username, api_key) VALUES ('bob', 'secrecy');

-- Tasks
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('alice', 'Task 1', 'Sample task 1', '2025-09-02', 'Consequence 1', 'NONE', 'NONE', 'NONE', 'NONE', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('bob', 'Task 2', 'Sample task 2', '2025-09-04', 'Consequence 2', 'SUBMIT', 'OPTIONAL', 'SUBMIT', 'OPTIONAL', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('alice', 'Task 3', 'Sample task 3', '2025-09-06', 'Consequence 3', 'SIGN', 'VOLUNTEER_OPPORTUNITY', 'ATTEND', 'VOLUNTEER_OPPORTUNITY', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('bob', 'Task 4', 'Sample task 4', '2025-09-08', 'Consequence 4', 'PAY', 'MANDATORY', 'SETUP', 'MANDATORY', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('alice', 'Task 5', 'Sample task 5', '2025-09-10', 'Consequence 5', 'PURCHASE', 'NONE', 'BRING', 'NONE', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('bob', 'Task 6', 'Sample task 6', '2025-09-12', 'Consequence 6', 'ATTEND', 'OPTIONAL', 'PREPARE', 'OPTIONAL', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('alice', 'Task 7', 'Sample task 7', '2025-09-14', 'Consequence 7', 'TRANSPORT', 'VOLUNTEER_OPPORTUNITY', 'WEAR', 'VOLUNTEER_OPPORTUNITY', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('bob', 'Task 8', 'Sample task 8', '2025-09-16', 'Consequence 8', 'VOLUNTEER', 'MANDATORY', 'COLLECT', 'MANDATORY', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('alice', 'Task 9', 'Sample task 9', '2025-09-18', 'Consequence 9', 'OTHER', 'NONE', 'OTHER', 'NONE', 'pending');
INSERT INTO tasks (user, title, description, due_date, consequence_if_ignore, parent_action, parent_requirement_level, student_action, student_requirement_level, status)
VALUES ('bob', 'Task 10', 'Sample task 10', NULL, 'Consequence 10', 'SUBMIT', 'OPTIONAL', 'ATTEND', 'OPTIONAL', 'pending');
