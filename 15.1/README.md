# Домашнее задание к занятию "15.1. Организация сети" - Бодарев В.В.

---
## Задание 1. Яндекс.Облако (обязательное к выполнению)

1. Создать VPC.
- Создать пустую VPC. Выбрать зону.
2. Публичная подсеть.
- Создать в vpc subnet с названием public, сетью 192.168.10.0/24.
- Создать в этой подсети NAT-инстанс, присвоив ему адрес 192.168.10.254. В качестве image_id использовать fd80mrhj8fl2oe87o4e1
- Создать в этой публичной подсети виртуалку с публичным IP и подключиться к ней, убедиться что есть доступ к интернету.
3. Приватная подсеть.
- Создать в vpc subnet с названием private, сетью 192.168.20.0/24.
- Создать route table. Добавить статический маршрут, направляющий весь исходящий трафик private сети в NAT-инстанс
- Создать в этой приватной подсети виртуалку с внутренним IP, подключиться к ней через виртуалку, созданную ранее и убедиться что есть доступ к интернету

---

1.Созданная публичная и приватная сеть

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/111.jpg)

2.Созданная таблица маршрутизации

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/112.jpg)

3.Созданные виртуальные машины

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/113.jpg)

4.Добавим ключ в ssh agent для проброса его к приватной виртуалке. Подключимся к публичной виртуалке.

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/114.jpg)

5.Убедимся что есть доступ к интернету

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/115.jpg)

6.Подключимся к приватной виртуалке

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/116.jpg)

7.Убедимся что мы подключились к приватной виртуалке и проверим доступ в интернет. Видим локальный ip адрес приватной виртуалки и ip адрес инстанса.

![image alt](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/117.jpg)

# Terraform код - [main](https://github.com/vasionxxx/clokub-homeworks/blob/clokub-5/data/main3.tf)
