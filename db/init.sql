CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

INSERT INTO users (name, email)
VALUES
    ('Nikhil', 'nikhil@example.com'),
    ('Tanuja', 'tanuja@example.com');
