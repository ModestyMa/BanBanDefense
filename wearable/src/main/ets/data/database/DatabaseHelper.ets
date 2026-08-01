// 【手表端副本】与 entry module 同步维护，V1.0 抽 HAR 后删除（SPEC_M6 决策 8）
// 数据库助手：单例管理 RdbStore，首版建全量 6 张表（SCHEMA 见 03 技术架构设计 / 06_AI_CONTEXT）
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const DB_NAME: string = 'banban.db';
const DB_VERSION: number = 1;

const SQL_CREATE_COUNTDOWN: string =
  'CREATE TABLE IF NOT EXISTS countdown_event (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
  'title TEXT NOT NULL,' +
  'target_date INTEGER NOT NULL,' +
  'is_lunar INTEGER NOT NULL DEFAULT 0,' +
  'repeat_rule TEXT,' +
  'category TEXT NOT NULL,' +
  'is_top INTEGER NOT NULL DEFAULT 0,' +
  'linked_account_id INTEGER,' +
  'note TEXT,' +
  'remind_enabled INTEGER NOT NULL DEFAULT 1,' +
  'reminder_ids TEXT,' +
  'created_at INTEGER NOT NULL)';

const SQL_CREATE_ACCOUNT: string =
  'CREATE TABLE IF NOT EXISTS account (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
  'name TEXT NOT NULL,' +
  'type TEXT NOT NULL,' +
  'balance REAL NOT NULL DEFAULT 0,' +
  'icon TEXT,' +
  'sort INTEGER NOT NULL DEFAULT 0,' +
  'created_at INTEGER NOT NULL)';

const SQL_CREATE_TRANSACTION: string =
  'CREATE TABLE IF NOT EXISTS transaction_record (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
  'account_id INTEGER NOT NULL,' +
  'amount REAL NOT NULL,' +
  'direction TEXT NOT NULL,' +
  'category TEXT NOT NULL,' +
  'counterparty TEXT,' +
  'trade_time INTEGER NOT NULL,' +
  'source TEXT NOT NULL,' +
  'external_no TEXT,' +
  'created_at INTEGER NOT NULL)';

const SQL_CREATE_POMODORO: string =
  'CREATE TABLE IF NOT EXISTS pomodoro_session (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
  'start_time INTEGER NOT NULL,' +
  'end_time INTEGER NOT NULL,' +
  'duration_min INTEGER NOT NULL,' +
  'tag TEXT NOT NULL,' +
  'event_id INTEGER)';

const SQL_CREATE_PET: string =
  'CREATE TABLE IF NOT EXISTS pet_state (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
  'level INTEGER NOT NULL DEFAULT 1,' +
  'exp INTEGER NOT NULL DEFAULT 0,' +
  'skin TEXT,' +
  'mood INTEGER NOT NULL DEFAULT 1,' +
  'streak_days INTEGER NOT NULL DEFAULT 0,' +
  'last_active_date INTEGER NOT NULL DEFAULT 0)';

const SQL_CREATE_IMPORT_BATCH: string =
  'CREATE TABLE IF NOT EXISTS import_batch (' +
  'id INTEGER PRIMARY KEY AUTOINCREMENT,' +
  'source TEXT NOT NULL,' +
  'file_name TEXT,' +
  'imported_count INTEGER NOT NULL DEFAULT 0,' +
  'created_at INTEGER NOT NULL)';

export class DatabaseHelper {
  private static store: relationalStore.RdbStore | null = null;
  // BUG-007：init 是异步的，页面 aboutToAppear 会抢在它完成前读库。
  // 缓存 in-flight Promise，让并发调用方共享同一次初始化并可等待（幂等）。
  private static initPromise: Promise<void> | null = null;
  private static ctx: common.Context | null = null;

  /** 应用启动时调用一次（EntryAbility.onCreate）；可并发重入，返回同一次初始化 */
  static async init(context: common.Context): Promise<void> {
    DatabaseHelper.ctx = context;
    if (DatabaseHelper.store !== null) {
      return;
    }
    if (DatabaseHelper.initPromise !== null) {
      await DatabaseHelper.initPromise;
      return;
    }
    DatabaseHelper.initPromise = DatabaseHelper.doInit(context);
    try {
      await DatabaseHelper.initPromise;
    } finally {
      // 失败时清空，允许后续重试；成功时保留（store 已非空，不会再走到这）
      if (DatabaseHelper.store === null) {
        DatabaseHelper.initPromise = null;
      }
    }
  }

  private static async doInit(context: common.Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };
    const store = await relationalStore.getRdbStore(context, config);
    await store.executeSql(SQL_CREATE_COUNTDOWN);
    await store.executeSql(SQL_CREATE_ACCOUNT);
    await store.executeSql(SQL_CREATE_TRANSACTION);
    await store.executeSql(SQL_CREATE_POMODORO);
    await store.executeSql(SQL_CREATE_PET);
    await store.executeSql(SQL_CREATE_IMPORT_BATCH);
    DatabaseHelper.store = store;
  }

  /**
   * BUG-007：页面/ViewModel 读库前必须先 await 本方法。
   * 已就绪则立即返回；初始化进行中则等它完成；尚未开始则用缓存的 context 补跑一次。
   */
  static async ready(): Promise<void> {
    if (DatabaseHelper.store !== null) {
      return;
    }
    if (DatabaseHelper.initPromise !== null) {
      await DatabaseHelper.initPromise;
      return;
    }
    if (DatabaseHelper.ctx !== null) {
      await DatabaseHelper.init(DatabaseHelper.ctx);
      return;
    }
    throw new Error('DatabaseHelper 未初始化，请先在 EntryAbility.onCreate 调用 init');
  }

  static get(): relationalStore.RdbStore {
    if (DatabaseHelper.store === null) {
      throw new Error('DatabaseHelper 未初始化，请先在 EntryAbility.onCreate 调用 init');
    }
    return DatabaseHelper.store;
  }

  static isReady(): boolean {
    return DatabaseHelper.store !== null;
  }

  static version(): number {
    return DB_VERSION;
  }

  /** 清除全部业务数据（6 表物理 DELETE，SPEC_M5 决策 9）；调用方负责先取消提醒、后刷新各 VM */
  static async clearAll(): Promise<void> {
    const store = DatabaseHelper.get();
    await store.executeSql('DELETE FROM countdown_event');
    await store.executeSql('DELETE FROM account');
    await store.executeSql('DELETE FROM transaction_record');
    await store.executeSql('DELETE FROM pomodoro_session');
    await store.executeSql('DELETE FROM pet_state');
    await store.executeSql('DELETE FROM import_batch');
  }
}
