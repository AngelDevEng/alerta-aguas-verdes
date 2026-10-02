import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthController } from './common/health.controller';
import { JwtAuthGuard } from './common/guards/jwt-auth.guard';
import { RolesGuard } from './common/guards/roles.guard';
import { AuthModule } from './auth/auth.module';
import { IncidenciasModule } from './incidencias/incidencias.module';
import { UnidadesModule } from './unidades/unidades.module';
import { EvidenciasModule } from './evidencias/evidencias.module';
import { AlertasModule } from './alertas/alertas.module';
import { CatalogosModule } from './catalogos/catalogos.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (cfg: ConfigService) => ({
        type: 'postgres' as const,
        url: cfg.getOrThrow<string>('DATABASE_URL'),
        ssl: cfg.get('DB_SSL') === 'false' ? false : { rejectUnauthorized: false }, // Supabase exige SSL
        synchronize: false,                    // el esquema se gestiona con /database/*.sql
      }),
    }),
    AuthModule,
    IncidenciasModule,
    UnidadesModule,
    EvidenciasModule,
    AlertasModule,
    CatalogosModule,
  ],
  controllers: [HealthController],
  providers: [
    // El orden importa: primero se autentica, despues se valida el rol.
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}