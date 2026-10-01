import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { HealthController } from './common/health.controller';
import { IncidenciasModule } from './incidencias/incidencias.module';
import { UnidadesModule } from './unidades/unidades.module';
import { EvidenciasModule } from './evidencias/evidencias.module';

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
    IncidenciasModule,
    UnidadesModule,
    EvidenciasModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
