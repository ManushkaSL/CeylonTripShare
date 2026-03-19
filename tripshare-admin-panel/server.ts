import express from "express";
import { createServer as createViteServer } from "vite";
import Database from "better-sqlite3";
import path from "path";
import { fileURLToPath } from "url";
import multer from "multer";
import fs from "fs";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, "uploads");
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
  filename: (_req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1e9);
    const ext = path.extname(file.originalname);
    cb(null, uniqueSuffix + ext);
  }
});

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

const db = new Database("tours.db");

// Initialize database
db.exec(`
  CREATE TABLE IF NOT EXISTS tours (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    category TEXT,
    description TEXT,
    price REAL,
    images TEXT,
    location TEXT,
    duration TEXT,
    start_time_location TEXT,
    last_joining_time TEXT,
    end_time_location TEXT,
    route TEXT,
    operator_name TEXT,
    whats_included TEXT,
    tour_features TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )
`);

// Migrate existing databases: add new columns if they don't exist
const columns = db.prepare("PRAGMA table_info(tours)").all().map((c: any) => c.name);
const newCols: [string, string][] = [
  ["category", "TEXT"],
  ["images", "TEXT"],
  ["start_time_location", "TEXT"],
  ["last_joining_time", "TEXT"],
  ["end_time_location", "TEXT"],
  ["route", "TEXT"],
  ["operator_name", "TEXT"],
  ["whats_included", "TEXT"],
  ["tour_features", "TEXT"],
];
for (const [col, type] of newCols) {
  if (!columns.includes(col)) {
    db.exec(`ALTER TABLE tours ADD COLUMN ${col} ${type}`);
  }
}

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json());

  // Serve uploaded images
  app.use("/uploads", express.static(uploadsDir));

  // API Routes
  app.get("/api/tours", (req, res) => {
    try {
      const tours = db.prepare("SELECT * FROM tours ORDER BY created_at DESC").all();
      res.json(tours);
    } catch (error) {
      res.status(500).json({ error: "Failed to fetch tours" });
    }
  });

  app.post("/api/tours", upload.array("images", 20), (req, res) => {
    const { title, category, description, price, location, duration, start_time_location, last_joining_time, end_time_location, route, operator_name, whats_included, tour_features } = req.body;
    if (!title) {
      return res.status(400).json({ error: "Title is required" });
    }
    try {
      const files = req.files as Express.Multer.File[];
      const imageFilenames = files ? files.map(f => f.filename) : [];
      const imagesJson = JSON.stringify(imageFilenames);

      const info = db.prepare(`
        INSERT INTO tours (title, category, description, price, images, location, duration, start_time_location, last_joining_time, end_time_location, route, operator_name, whats_included, tour_features)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(title, category, description, price, imagesJson, location, duration, start_time_location, last_joining_time, end_time_location, route, operator_name, whats_included, tour_features);
      
      const newTour = db.prepare("SELECT * FROM tours WHERE id = ?").get(info.lastInsertRowid);
      res.status(201).json(newTour);
    } catch (error) {
      res.status(500).json({ error: "Failed to create tour" });
    }
  });

  app.delete("/api/tours/:id", (req, res) => {
    const { id } = req.params;
    try {
      const result = db.prepare("DELETE FROM tours WHERE id = ?").run(id);
      if (result.changes === 0) {
        return res.status(404).json({ error: "Tour not found" });
      }
      res.status(204).send();
    } catch (error) {
      res.status(500).json({ error: "Failed to delete tour" });
    }
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    app.use(express.static(path.join(__dirname, "dist")));
    app.get("*", (req, res) => {
      res.sendFile(path.join(__dirname, "dist", "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
