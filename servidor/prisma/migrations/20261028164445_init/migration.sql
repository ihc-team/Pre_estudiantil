-- CreateTable
CREATE TABLE "usuarios" (
    "id" SERIAL NOT NULL,
    "nombre" VARCHAR(100) NOT NULL,
    "correo" VARCHAR(150) NOT NULL,
    "contrasena_hash" VARCHAR(255) NOT NULL,
    "creado_en" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "sesiones" (
    "id" SERIAL NOT NULL,
    "token" VARCHAR(255) NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "creado_en" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expira_en" TIMESTAMP(6) NOT NULL,

    CONSTRAINT "sesiones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "recuperaciones" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "codigo" CHAR(6) NOT NULL,
    "creado_en" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expira_en" TIMESTAMP(6) NOT NULL,
    "usado" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "recuperaciones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "movimientos" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "concepto" VARCHAR(150) NOT NULL,
    "monto" DECIMAL(12,2) NOT NULL,
    "fecha" DATE NOT NULL,
    "tipo" VARCHAR(10) NOT NULL DEFAULT 'gasto',
    "categoria" VARCHAR(20) NOT NULL DEFAULT 'otros',
    "estado" VARCHAR(10) NOT NULL DEFAULT 'pendiente',
    "creado_en" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "movimientos_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "movimientos_monto_check" CHECK ("monto" > 0),
    CONSTRAINT "movimientos_tipo_check" CHECK ("tipo" IN ('ingreso', 'gasto')),
    CONSTRAINT "movimientos_categoria_check" CHECK ("categoria" IN ('comida', 'transporte', 'estudio', 'otros')),
    CONSTRAINT "movimientos_estado_check" CHECK ("estado" IN ('pendiente', 'pagado'))
);

-- CreateTable
CREATE TABLE "limites_mensuales" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "mes" DATE NOT NULL,
    "monto" DECIMAL(10,2) NOT NULL,
    "actualizado_en" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "limites_mensuales_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "limites_mensuales_monto_check" CHECK ("monto" > 0)
);

-- CreateTable
CREATE TABLE "eventos" (
    "id" SERIAL NOT NULL,
    "usuario_id" INTEGER NOT NULL,
    "tipo" VARCHAR(30) NOT NULL,
    "movimiento_id" INTEGER,
    "monto" DECIMAL(12,2),
    "descripcion" VARCHAR(200),
    "creado_en" TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "eventos_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "eventos_tipo_check" CHECK ("tipo" IN ('gasto_registrado', 'ingreso_registrado',
                                     'movimiento_pagado', 'limite_definido'))
);

-- CreateIndex
CREATE UNIQUE INDEX "usuarios_correo_key" ON "usuarios"("correo");

-- CreateIndex
CREATE UNIQUE INDEX "sesiones_token_key" ON "sesiones"("token");

-- CreateIndex
CREATE UNIQUE INDEX "limites_mensuales_usuario_id_mes_key" ON "limites_mensuales"("usuario_id", "mes");

-- CreateIndex
CREATE INDEX "idx_eventos_usuario_fecha" ON "eventos"("usuario_id", "creado_en" DESC);

-- AddForeignKey
ALTER TABLE "sesiones" ADD CONSTRAINT "sesiones_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE;

-- AddForeignKey
ALTER TABLE "recuperaciones" ADD CONSTRAINT "recuperaciones_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE;

-- AddForeignKey
ALTER TABLE "movimientos" ADD CONSTRAINT "movimientos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE;

-- AddForeignKey
ALTER TABLE "limites_mensuales" ADD CONSTRAINT "limites_mensuales_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE;

-- AddForeignKey
ALTER TABLE "eventos" ADD CONSTRAINT "eventos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE;

-- AddForeignKey
ALTER TABLE "eventos" ADD CONSTRAINT "eventos_movimiento_id_fkey" FOREIGN KEY ("movimiento_id") REFERENCES "movimientos"("id") ON DELETE SET NULL;
