-- Tarea 5 Proyecto recibido
-- Presupuesto planeado por usuario, mes y categoria especifica
CREATE TABLE presupuestos_por_categoria (
    id                SERIAL PRIMARY KEY,
    usuario_id        INTEGER NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    mes               DATE NOT NULL,
    categoria         VARCHAR(20) NOT NULL CHECK (categoria IN ('comida', 'transporte', 'estudio', 'otros')),
    monto             NUMERIC(10,2) NOT NULL CHECK (monto > 0),
    actualizado_en    TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (usuario_id, mes, categoria)
);