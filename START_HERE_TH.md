# เริ่มต้นใน Claude Code

## ชุดนี้มีอะไร

| ไฟล์ | ใช้ทำอะไร |
| --- | --- |
| `CLAUDE.md` | Claude Code อ่านทุกครั้งที่เปิด repo — สรุปเกม การตัดสินใจทางเทคนิค กฎสถาปัตยกรรม งบประสิทธิภาพ |
| `docs/GDD.md` | Game Design Document ฉบับเต็ม (export จากเอกสารออนไลน์ ณ 25 ต.ค. 2026) |
| `docs/PHASE0.md` | งานเฟส 0 (spike 4 ข้อ) พร้อมเกณฑ์ผ่าน |
| `docs/DECISIONS.md` | บันทึกการตัดสินใจทั้งหมด เพิ่มแถวใหม่ไว้บนสุดทุกครั้งที่ตัดสินใจ |
| `docs/art/` | ภาพจำลอง — `03`/`04` คือสไตล์ 1.5 ที่เลือก |
| `tools/blender/` | script สร้างฉาก/asset จากโค้ด (`tools/README.md` บอกวิธีรัน) |

## ขั้นตอน

1. ติดตั้ง Godot 4 เวอร์ชัน stable ล่าสุด (มาตรฐาน ไม่ใช่ .NET) และ export templates
2. สร้าง GitHub repo ว่าง เช่น `drowned-city` แล้ว clone ลงเครื่อง
3. คัดลอกทุกไฟล์ในโฟลเดอร์นี้ลงใน repo → commit แรก
4. GitHub → Settings → Pages → Source: **GitHub Actions**
5. เปิด Claude Code ในโฟลเดอร์ repo แล้ววาง prompt ด้านล่าง

## Prompt แรก

```
อ่าน CLAUDE.md, docs/PHASE0.md และ docs/DECISIONS.md ก่อน แล้วเริ่มเฟส 0 ข้อ 0.1 และ 0.2:
ตั้งโปรเจกต์ Godot (Compatibility renderer, web export แบบ single-thread), โครงโฟลเดอร์ตาม CLAUDE.md,
เลือก test framework, ตัวแสดง build number + F3 debug overlay และ GitHub Actions ที่ export เว็บ
แล้ว deploy ขึ้น GitHub Pages ทำเป็น PR เล็กๆ และบอกว่าฉันต้องทดสอบอะไรบ้าง
```

## หลังจากนั้น

- ทำ 0.3 → 0.6 ทีละข้อ ทดสอบบน laptop Arc ทุกข้อ แล้วบันทึกผลใน `docs/PHASE0_RESULTS.md`
- ถ้าแก้การออกแบบ ให้แก้ทั้ง `docs/GDD.md` และเอกสารออนไลน์ (หรือบอก Claude ให้ทำ)
- เอกสารออนไลน์ (แก้ไข/คอมเมนต์ได้): https://claude.ai/artifact/4cij3hzxQCwe3dT9TdsDVg
